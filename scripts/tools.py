import os
import pandas as pd
import pyodbc
# from azure.core.credentials import TokenCredential
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from openai import AzureOpenAI
from serpapi import GoogleSearch
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.units import inch
from typing import Any, Callable, Set
from opentelemetry import trace
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential(
    exclude_environment_credential=False,
    exclude_managed_identity_credential=False,
    exclude_shared_token_cache_credential=True,   # skip local cache
    exclude_visual_studio_code_credential=True,
)

key_vault = SecretClient(vault_url=os.environ["KEYVAULT_URL"], credential=credential)

tracer = trace.get_tracer(__name__)


@tracer.start_as_current_span("search_acc_guidelines")  # type: ignore
def search_acc_guidelines(query: str) -> str:
    """
    Searches the Azure AI Search index 'acc-guidelines-index'
    for relevant American College of Cardiology (ACC) guidelines.
    """
    
    try:
        credential = DefaultAzureCredential()
        # AZURE_SEARCH_ENDPOINT = key_vault.get_secret("azure-search-endpoint").value
        AZURE_SEARCH_ENDPOINT = os.environ["AZURE_SEARCH_ENDPOINT"]
        SEARCH_INDEX_NAME = key_vault.get_secret("azureai-search-index-name").value
        AOAI_ENDPOINT = key_vault.get_secret("azure-openai-endpoint").value
        AOAI_API_VERSION = "2024-04-01-preview"
        AOAI_EMBEDDING_DEPLOYMENT = key_vault.get_secret("azure-openai-embedding-deployment").value
        
        aad_token = DefaultAzureCredential().get_token("https://cognitiveservices.azure.com/.default").token
        aoai_client = AzureOpenAI(
            azure_ad_token=aad_token,
            azure_endpoint=AOAI_ENDPOINT,
            api_version=AOAI_API_VERSION,
        )
        qvec = aoai_client.embeddings.create(
            model=AOAI_EMBEDDING_DEPLOYMENT,
            input=query
        ).data[0].embedding
        
        client = SearchClient(
            endpoint=AZURE_SEARCH_ENDPOINT,
            index_name=SEARCH_INDEX_NAME,
            credential=credential,
        )
        
        span = trace.get_current_span()
        span.set_attribute("search_index_query", query)
        results = client.search(
            search_text=query,
            vector_queries=[
                        VectorizedQuery(
                            vector = qvec,
                            k_nearest_neighbors=10,
                            fields="content_vector"
                        )
            ],
            search_fields=["content"],
            top=10,
            include_total_count=True,
        )
        retrieved_texts = [result.get("content", "") for result in results]
        context_str = (
            "\n".join(retrieved_texts)
            if retrieved_texts
            else "No relevant guidelines found."
        )
        return context_str

    except Exception as e:
        
        return f"Error {e}"
    
@tracer.start_as_current_span("search_serpapi_web")  # type: ignore
def search_serpapi_web(query: str, num_results: int = 5) -> str:
    """
    Perform a Google search using SerpAPI and return summarized top results.

    Args:
        query (str): The search query string.
        num_results (int): Number of top results to retrieve.

    Returns:
        str: A formatted string of search results.
    """
    
    SERPAPI_API_KEY = key_vault.get_secret("serp-api-key").value
    if not SERPAPI_API_KEY:
        return "❌ SerpAPI key is not set. Please check your .env file."

    params = {
        "engine": "google",
        "q": query,
        "api_key": SERPAPI_API_KEY,
        "num": num_results,
        "hl": "en",
    }

    try:
        span = trace.get_current_span()
        span.set_attribute("requested_web_search", query)
        
        search = GoogleSearch(params)
        results = search.get_dict()

        if "error" in results:
            return f"❌ SerpAPI error: {results['error']}"

        snippets = []
        for idx, result in enumerate(results.get("organic_results", []), 1):
            title = result.get("title", "No title")
            snippet = result.get("snippet", "No snippet available.")
            link = result.get("link", "No link")
            snippets.append(f"{idx}. **{title}**\n{snippet}\n🔗 {link}")

        return "\n\n".join(snippets) if snippets else "No results found."
    

    except Exception as e:
        return f"❌ SerpAPI request failed: {str(e)}"


@tracer.start_as_current_span("lookup_patient_data")  # type: ignore
def lookup_patient_data(query: str) -> str:
    """
    Queries the 'PatientMedicalData' table in Azure SQL and returns the results as a string.
    'query' should be a valid SQL statement.
    """
    try:
        
        span = trace.get_current_span()
        span.set_attribute("patient_data_query", query)
        
        server = key_vault.get_secret("azure-sql-server").value
        database = key_vault.get_secret("azure-sql-database").value        # Replace with your database name
        username = key_vault.get_secret("azure-sql-username").value        # Replace with your username
        password = key_vault.get_secret("azure-sql-password").value        # Replace with your password
        driver = '{ODBC Driver 18 for SQL Server}'
        connection_string = f'DRIVER={driver};SERVER={server};DATABASE={database};UID={username};PWD={password}'
        engine = pyodbc.connect(connection_string, timeout=30)
        print("DONE!!!!!")
        df = pd.read_sql(query, engine)
        if df.empty:
            return "No rows found."
        return df.to_string(index=False)
    except Exception as e:
        return f"Database error: {str(e)}"
    
    
@tracer.start_as_current_span("generate_discharge_summary")  # type: ignore
def generate_discharge_summary(patient_name: str, diagnosis: str, treatment: str, follow_up_instructions: str = "") -> dict:
    """
    Generate a discharge summary PDF for a patient.

    Args:
        patient_name (str): Name of the patient.
        diagnosis (str): Diagnosis information.
        treatment (str): Treatment details.
        follow_up_instructions (str, optional): Post-treatment instructions.

    Returns:
        dict: Contains the local file path to the generated PDF.
    """

    # Prepare output directory and file name
    
    span = trace.get_current_span()
    span.set_attribute("patient_name", patient_name)
    span.set_attribute("diagnosis", diagnosis)
    span.set_attribute("treatment", treatment)
    span.set_attribute("follow_up_instructions", follow_up_instructions)
    
    
    output_dir = "discharge_summaries"
    os.makedirs(output_dir, exist_ok=True)
    safe_name = patient_name.replace(" ", "_").lower()
    file_path = os.path.join(output_dir, f"{safe_name}_discharge_summary.pdf")

    # Create PDF document
    doc = SimpleDocTemplate(file_path, pagesize=A4)
    elements = []

    # Styles
    styles = getSampleStyleSheet()
    style_heading = styles['Heading1']
    style_label = ParagraphStyle(name="Label", fontSize=12, fontName="Helvetica-Bold")
    style_text = ParagraphStyle(name="Text", fontSize=12, fontName="Helvetica")

    # Header
    elements.append(Paragraph("Discharge Summary", style_heading))
    elements.append(Spacer(1, 0.3 * inch))

    # Patient Name
    elements.append(Paragraph("Patient Name:", style_label))
    elements.append(Paragraph(patient_name, style_text))
    elements.append(Spacer(1, 0.2 * inch))

    # Diagnosis
    elements.append(Paragraph("Diagnosis:", style_label))
    elements.append(Paragraph(diagnosis, style_text))
    elements.append(Spacer(1, 0.2 * inch))

    # Treatment
    elements.append(Paragraph("Treatment:", style_label))
    elements.append(Paragraph(treatment, style_text))
    elements.append(Spacer(1, 0.2 * inch))

    # Follow-up Instructions
    elements.append(Paragraph("Follow-Up Instructions:", style_label))
    elements.append(Paragraph(follow_up_instructions or "N/A", style_text))
    elements.append(Spacer(1, 0.2 * inch))

    # Build the PDF
    
    doc.build(elements)
    # Make the file available to download in Chainlit
    file_path = os.path.join(output_dir, f"{safe_name}_discharge_summary.pdf")
    
    return f"Discharge summary generated and available for download. {file_path}"


user_functions: Set[Callable[..., Any]] = {
    search_acc_guidelines,
    search_serpapi_web,
    lookup_patient_data,
    generate_discharge_summary
}