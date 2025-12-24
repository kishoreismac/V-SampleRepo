import logging

from azure.ai.projects import AIProjectClient
from azure.ai.agents.models import ToolSet
from azure.ai.agents.models import FunctionTool
from opentelemetry import trace
from azure.monitor.opentelemetry import configure_azure_monitor
from azure.identity import DefaultAzureCredential
from tools import user_functions
from pathlib import Path
import logging
import os

logging.getLogger("azure").setLevel(logging.WARNING)
logging.getLogger("opentelemetry").setLevel(logging.WARNING)

logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger(__name__)

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient


credential = DefaultAzureCredential(
    exclude_environment_credential=False,
    exclude_managed_identity_credential=False,
    exclude_shared_token_cache_credential=True,   # skip local cache
    exclude_visual_studio_code_credential=True,
)

key_vault = SecretClient(vault_url=os.environ["KEYVAULT_URL"], credential=credential)


functions = FunctionTool(user_functions)

toolset = ToolSet()
toolset.add(functions)


agents_client = AIProjectClient.from_connection_string(
    key_vault.get_secret("ai-project-conn-string").value,
    credential=DefaultAzureCredential(),
)
agent_client = agents_client.agents

application_insights_connection_string = agents_client.telemetry.get_connection_string()

configure_azure_monitor(connection_string=application_insights_connection_string)

scenario = Path(__file__).name
tracer = trace.get_tracer(__name__)


async def creating_agent():
    """Initialize the agent with the sales data schema and instructions."""

    if not key_vault.get_secret("model-deployment-name").value:
        logger.error("MODEL_DEPLOYMENT_NAME environment variable is not set")
        return None, None

    # await add_agent_tools()

    try:

        with open("instructions.txt", "rb") as f:
            instructions = f.read()

        # agent_client.enable_auto_function_calls(toolset)
        with tracer.start_as_current_span(scenario):

            agent = agent_client.create_agent(
                model=key_vault.get_secret("model-deployment-name").value,
                name="healthcare_agent",
                instructions=instructions,
                toolset=toolset,
            )

            print(f"Created agent, ID: {agent.id}")

            key_vault.set_secret(name="agent-id", value=agent.id)

    except Exception as e:
        logger.error("An error occurred creating agent: %s", str(e))


if __name__ == "__main__":

    creating_agent()
