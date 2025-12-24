import os
import chainlit as cl
from chainlit import Starter
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.ai.projects import AIProjectClient
from azure.ai.agents.models import ToolSet, FunctionTool
from scripts.tools import user_functions


uami_client_id = os.environ["AZURE_CLIENT_ID"]  # you exported this in pipeline

# Force DefaultAzureCredential to use UAMI
credential = DefaultAzureCredential(
    managed_identity_client_id=uami_client_id,
    exclude_cli_credential=True,                # <-- important: skip Azure CLI login
    exclude_powershell_credential=True,
    exclude_developer_cli_credential=True
)


# Key Vault clients (fetch once, reuse)
kv = SecretClient(vault_url=os.environ["KEYVAULT_URL"], credential=credential)

# Pull secrets once and cache in memory
AIPROJECT_CONN_STR = kv.get_secret("ai-project-conn-string").value
AGENT_ID = kv.get_secret("agent-id").value


# AI Project client (reuse across requests)
project_client = AIProjectClient.from_connection_string(
    AIPROJECT_CONN_STR, credential=credential
)

agent_client = project_client.agents

# Tools
functions = FunctionTool(user_functions)
toolset = ToolSet()
toolset.add(functions)


# ---------- Helpers ----------

def get_or_create_user_thread_id(user_id: str) -> str:
    
    """
    Return an existing thread_id for this user if present in session,
    otherwise create a new thread and store it in the session.
    """
    
    # Chainlit user-scoped memory
    thread_id = cl.user_session.get("thread_id")
    if thread_id:
        return thread_id

    thread = agent_client.create_thread()
    cl.user_session.set("thread_id", thread.id)
    return thread.id


def reset_user_thread():
    
    """Forget the stored thread_id so a new one is created next message."""
    cl.user_session.set("thread_id", None)


# ---------- Core run ----------


async def run_multi_step_agent(user_id: str, user_query: str):
    
    thread_id = get_or_create_user_thread_id(user_id)

    # Add the user message to the (user-specific) thread
    agent_client.create_message(thread_id=thread_id, role="user", content=user_query)

    # Process a run against your existing Agent (ID from Key Vault), using your toolset
    run = agent_client.create_and_process_run(
        thread_id=thread_id, assistant_id=AGENT_ID, toolset=toolset
    )

    # Fetch the new messages for this run only (keeps the list small)
    messages = agent_client.list_messages(thread_id=thread_id, run_id=run.id)
    last_msg = messages.get_last_text_message_by_role("assistant")

    reply = last_msg.text.value if last_msg else "I couldn't generate a response."
    await cl.Message(content=reply, author="Agent").send()


# ---------- UI bits ----------


@cl.action_callback("clear_history")
async def on_clear_history(action):
    reset_user_thread()  # make the next user message start a fresh thread
    await cl.Message(
        content="✅ History cleared and thread reset for this session."
    ).send()
    await action.remove()


@cl.set_starters
async def set_starters():
    return [
        Starter(
            label="💊 How many patients have Hypertension and are prescribed Lisinopril? (NL2SQL)",
            message="How many patients have Hypertension and are prescribed Lisinopril?",
        ),
        Starter(
            label="❓ As of Feb 2025, new anticoagulant therapies from the FDA? (Google Search)",
            message="Are there any recent updates in 2025 on new anticoagulant therapies from the FDA?",
        ),
        Starter(
            label="❤️ ACC guidelines for hypertension (AZURE AI SEARCH)",
            message="What does the ACC recommend as first-line therapy for hypertension in elderly patients?",
        ),
        Starter(
            label="👵 Mega Query for 79-Year-Old Gloria Paul with hyperlipidemia (AGENTIC SEARCH)",
            message=(
                "I have a 79-year-old patient named Gloria Paul with hyperlipidemia. "
                "She's on Atorvastatin. Can you confirm her medical details from the database, "
                "check the ACC guidelines for hyperlipidemia, and see if there are any new medication "
                "updates from the FDA as of Feb 2025? Then give me a summary."
            ),
        ),
    ]


@cl.on_message
async def main(message: cl.Message):
    user_id = message.author
    await run_multi_step_agent(user_id=user_id, user_query=message.content)
