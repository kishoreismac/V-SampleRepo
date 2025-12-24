import json
import logging
import os
import subprocess
 
from azure.core.exceptions import ResourceExistsError
from azure.identity import AzureDeveloperCliCredential, DefaultAzureCredential
from azure.core.credentials import AzureKeyCredential
from azure.search.documents.indexes import SearchIndexClient, SearchIndexerClient
from azure.search.documents.indexes.models import (
    AzureOpenAIEmbeddingSkill,
    AzureOpenAIVectorizerParameters,
    AzureOpenAIVectorizer,
    FieldMapping,
    HnswAlgorithmConfiguration,
    HnswParameters,
    IndexProjectionMode,
    InputFieldMappingEntry,
    OutputFieldMappingEntry,
    SearchableField,
    SearchField,
    SearchFieldDataType,
    SearchIndex,
    SearchIndexer,
    SearchIndexerDataContainer,
    SearchIndexerDataSourceConnection,
    SearchIndexerDataSourceType,
    SearchIndexerIndexProjection,
    SearchIndexerIndexProjectionSelector,
    SearchIndexerIndexProjectionsParameters,
    SearchIndexerSkillset,
    SemanticConfiguration,
    SemanticField,
    SemanticPrioritizedFields,
    SemanticSearch,
    SimpleField,
    SplitSkill,
    VectorSearch,
    VectorSearchAlgorithmMetric,
    VectorSearchProfile,
)
from azure.storage.blob import BlobServiceClient
from dotenv import load_dotenv
from azure.keyvault.secrets import SecretClient


load_dotenv()

credential = DefaultAzureCredential(
    exclude_environment_credential=False,
    exclude_managed_identity_credential=False,
    exclude_shared_token_cache_credential=True,  # skip local cache
    exclude_visual_studio_code_credential=True,
)

key_vault = SecretClient(vault_url=os.environ["KEYVAULT_URL"], credential=credential)
  
 
def setup_index(
    azure_credential,
    index_name,
    azure_search_endpoint,
    azure_storage_connection_string,
    azure_storage_container,
    azure_openai_embedding_endpoint,
    azure_openai_embedding_deployment,
    azure_openai_embedding_model,
    azure_openai_embeddings_dimensions
):
    index_client = SearchIndexClient(azure_search_endpoint, azure_credential)
    indexer_client = SearchIndexerClient(azure_search_endpoint, azure_credential)
 
    # -----------------------------
    # Data source
    # -----------------------------
    data_source_connections = indexer_client.get_data_source_connections()
    if index_name not in [ds.name for ds in data_source_connections]:
        indexer_client.create_data_source_connection(
            data_source_connection=SearchIndexerDataSourceConnection(
                name=index_name,
                type=SearchIndexerDataSourceType.AZURE_BLOB,
                connection_string=azure_storage_connection_string,
                container=SearchIndexerDataContainer(name=azure_storage_container)
            )
        )
 
    # -----------------------------
    # Index
    # -----------------------------
    index_names = [index.name for index in index_client.list_indexes()]
    if index_name not in index_names:
        index_client.create_index(
            SearchIndex(
                name=index_name,
                fields=[
                    # Key field must be SimpleField, not searchable
                    SimpleField(name="chunk_id", type=SearchFieldDataType.String, key=True, filterable=True),
                    SimpleField(name="parent_id", type=SearchFieldDataType.String, filterable=True),
                    SearchableField(name="title"),
                    SearchableField(name="chunk"),
                    SearchField(
                        name="text_vector",
                        type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
                        vector_search_dimensions=azure_openai_embeddings_dimensions,
                        vector_search_profile_name="vp",
                        stored=True,
                        hidden=False
                    )
                ],
                vector_search=VectorSearch(
                    algorithms=[
                        HnswAlgorithmConfiguration(
                            name="algo",
                            parameters=HnswParameters(metric=VectorSearchAlgorithmMetric.COSINE)
                        )
                    ],
                    vectorizers=[
                        AzureOpenAIVectorizer(
                            vectorizer_name="openai_vectorizer",
                            parameters=AzureOpenAIVectorizerParameters(
                                resource_url=azure_openai_embedding_endpoint,
                                deployment_name=azure_openai_embedding_deployment,
                                model_name=azure_openai_embedding_model,
                                dimensions=azure_openai_embeddings_dimensions
                            )
                        )
                    ],
                    profiles=[
                        VectorSearchProfile(name="vp", algorithm_configuration_name="algo", vectorizer_name="openai_vectorizer")
                    ]
                ),
                semantic_search=SemanticSearch(
                    configurations=[
                        SemanticConfiguration(
                            name="default",
                            prioritized_fields=SemanticPrioritizedFields(
                                title_field=SemanticField(field_name="title"),
                                content_fields=[SemanticField(field_name="chunk")]
                            )
                        )
                    ],
                    default_configuration_name="default"
                )
            )
        )
 
    # -----------------------------
    # Skillset
    # -----------------------------
    skillsets = indexer_client.get_skillsets()
    if index_name not in [skillset.name for skillset in skillsets]:
        indexer_client.create_skillset(
            skillset=SearchIndexerSkillset(
                name=index_name,
                skills=[
                    SplitSkill(
                        text_split_mode="pages",
                        context="/document",
                        maximum_page_length=2000,
                        page_overlap_length=500,
                        inputs=[InputFieldMappingEntry(name="text", source="/document/content")],
                        outputs=[OutputFieldMappingEntry(name="textItems", target_name="pages")]
                    ),
                    AzureOpenAIEmbeddingSkill(
                        context="/document/pages/*",
                        resource_url=azure_openai_embedding_endpoint,
                        deployment_name=azure_openai_embedding_deployment,
                        model_name=azure_openai_embedding_model,
                        dimensions=azure_openai_embeddings_dimensions,
                        inputs=[InputFieldMappingEntry(name="text", source="/document/pages/*")],
                        outputs=[OutputFieldMappingEntry(name="embedding", target_name="embedding")]
                    )
                ],
                index_projections=SearchIndexerIndexProjection(
                    selectors=[
                        SearchIndexerIndexProjectionSelector(
                            target_index_name=index_name,
                            parent_key_field_name="parent_id",
                            source_context="/document/pages/*",
                            mappings=[
                                InputFieldMappingEntry(name="chunk", source="/document/pages/*"),
                                InputFieldMappingEntry(name="text_vector", source="/document/pages/*/embedding"),
                                InputFieldMappingEntry(name="title", source="/document/metadata_storage_name")
                            ]
                        )
                    ],
                    parameters=SearchIndexerIndexProjectionsParameters(
                        projection_mode=IndexProjectionMode.SKIP_INDEXING_PARENT_DOCUMENTS
                    )
                )
            )
        )
 
    # -----------------------------
    # Indexer
    # -----------------------------
    indexers = indexer_client.get_indexers()
    if index_name not in [indexer.name for indexer in indexers]:
        indexer_client.create_indexer(
            indexer=SearchIndexer(
                name=index_name,
                data_source_name=index_name,
                skillset_name=index_name,
                target_index_name=index_name,
                field_mappings=[FieldMapping(source_field_name="metadata_storage_name", target_field_name="title")]
            )
        )
 
 
def upload_documents(azure_credential, indexer_name, azure_search_endpoint, azure_storage_conn_string, azure_storage_container):
    indexer_client = SearchIndexerClient(azure_search_endpoint, azure_credential)
 
    blob_client = BlobServiceClient.from_connection_string(
        conn_str=azure_storage_conn_string,
        max_single_put_size=4 * 1024 * 1024
    )
    container_client = blob_client.get_container_client(azure_storage_container)
    if not container_client.exists():
        container_client.create_container()
    existing_blobs = [blob.name for blob in container_client.list_blobs()]
 
    for file in os.scandir("../data"):
        with open(file.path, "rb") as opened_file:
            filename = os.path.basename(file.path)
            if filename not in existing_blobs:
                container_client.upload_blob(filename, opened_file, overwrite=True)
 
    try:
        indexer_client.run_indexer(indexer_name)
        logger.info("Indexer started. Any unindexed blobs should be indexed in a few minutes, check the Azure Portal for status.")
    except ResourceExistsError:
        logger.info("Indexer already running, not starting again")
 
 
if __name__ == "__main__":
    logger = logging.getLogger("voicerag")
    logger.setLevel(logging.INFO)
 
    if os.getenv("AZURE_SEARCH_REUSE_EXISTING") == "true":
        logger.info("Using existing Azure AI Search index, no changes made.")
        exit()
 
    AZURE_SEARCH_INDEX = key_vault.get_secret("azureai-search-index-name").value
    AZURE_OPENAI_EMBEDDING_ENDPOINT = key_vault.get_secret("azure-openai-endpoint").value
    AZURE_OPENAI_EMBEDDING_DEPLOYMENT = key_vault.get_secret("azure-openai-embedding-deployment").value
    AZURE_OPENAI_EMBEDDING_MODEL = key_vault.get_secret("azure-openai-embedding-deployment").value
    EMBEDDINGS_DIMENSIONS = 1536
    AZURE_SEARCH_ENDPOINT = key_vault.get_secret("azure-search-endpoint").value
    AZURE_STORAGE_ENDPOINT = key_vault.get_secret('storage-endpoint').value
    AZURE_STORAGE_CONNECTION_STRING = key_vault.get_secret("storage-conn-string").value
    AZURE_STORAGE_CONTAINER = key_vault.get_secret('storage-container').value
 
    def get_search_credential():
        admin_key = os.getenv("AZURE_SEARCH_ADMIN_KEY")
        if admin_key:
            return AzureKeyCredential(admin_key)
        return credential
 
    azure_credential = get_search_credential()
 
    setup_index(
        azure_credential,
        index_name=AZURE_SEARCH_INDEX,
        azure_search_endpoint=AZURE_SEARCH_ENDPOINT,
        azure_storage_connection_string=AZURE_STORAGE_CONNECTION_STRING,
        azure_storage_container=AZURE_STORAGE_CONTAINER,
        azure_openai_embedding_endpoint=AZURE_OPENAI_EMBEDDING_ENDPOINT,
        azure_openai_embedding_deployment=AZURE_OPENAI_EMBEDDING_DEPLOYMENT,
        azure_openai_embedding_model=AZURE_OPENAI_EMBEDDING_MODEL,
        azure_openai_embeddings_dimensions=EMBEDDINGS_DIMENSIONS
    )
 
    upload_documents(
        azure_credential,
        indexer_name=AZURE_SEARCH_INDEX,
        azure_search_endpoint=AZURE_SEARCH_ENDPOINT,
        azure_storage_endpoint=AZURE_STORAGE_ENDPOINT,
        azure_storage_container=AZURE_STORAGE_CONTAINER,
        azure_storage_conn_string=AZURE_STORAGE_CONNECTION_STRING
    )
 