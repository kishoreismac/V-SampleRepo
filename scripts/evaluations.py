from azure.ai.evaluation import evaluate, RelevanceEvaluator, AzureOpenAIModelConfiguration
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.agents.models import (
    ToolSet
)
from azure.ai.agents.models import FunctionTool
from azure.keyvault.secrets import SecretClient
import os
from tools import user_functions


credential = DefaultAzureCredential(
    exclude_environment_credential=False,
    exclude_managed_identity_credential=False,
    exclude_shared_token_cache_credential=True,   # skip local cache
    exclude_visual_studio_code_credential=True,
)

key_vault = SecretClient(vault_url=os.getenv("KEYVAULT_URL"), credential=credential)

agents_client = AIProjectClient.from_connection_string(
    key_vault.get_secret("ai-project-conn-string").value,
    credential=DefaultAzureCredential())
agent_client = agents_client.agents

functions = FunctionTool(user_functions)

toolset = ToolSet()
toolset.add(functions) 

model_config = AzureOpenAIModelConfiguration(
    azure_endpoint=key_vault.get_secret("azure-openai-endpoint").value,
    api_version="2024-04-01-preview",
    azure_deployment=key_vault.get_secret("model-deployment-name").value,
)


evaluator = RelevanceEvaluator(model_config=model_config)

def get_agents_response(question):
    
    thread = agent_client.create_thread()
    # print(f"Created thread, ID: {thread.id}")
    
    message = agent_client.create_message(
        thread_id=thread.id,
        role="user",
        content=question)

    print(f"Created message, ID: {message.id}")

    run = agent_client.create_and_process_run(thread_id = thread.id, assistant_id=key_vault.get_secret("agent-id").value, toolset=toolset)
    
        # Fetch and log all messages
    messages = agent_client.list_messages(thread_id=thread.id, run_id= run.id)
    
    # print(f"Messages: {messages.data[-1]}")
    
    last_msg = messages.get_last_text_message_by_role("assistant")
    
    print("Message: ", last_msg.text.value)

    return {"response": last_msg.text.value}

def eval_run_eval():
    """
    Evaluate the model using the given data and column mapping.
    """

    result = evaluate(
        data = "../evaluation_data/evaluation_data.jsonl",
        target=get_agents_response,
        evaluation_name="evaluate_health_agent_score",
        evaluators={
            "relevance": evaluator,
        },
        azure_ai_project=agents_client.scope,
        output_path=f"../scripts/evaluation.json"
        
    )
    return result



if __name__ == '__main__':
    eval_run_eval()