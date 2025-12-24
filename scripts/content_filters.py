import requests
from dotenv import load_dotenv
import os
from azure.identity import DefaultAzureCredential
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient


credential = DefaultAzureCredential(
    exclude_environment_credential=False,
    exclude_managed_identity_credential=False,
    exclude_shared_token_cache_credential=True,  # skip local cache
    exclude_visual_studio_code_credential=True,
)


key_vault = SecretClient(vault_url=os.environ["KEYVAULT_URL"], credential=credential)


token = credential.get_token("https://management.azure.com/.default").token


# Azure AI Management API to configure the Content Filter
subscription_id = key_vault.get_secret("subscription-id").value
resource_group_name = key_vault.get_secret("rgName").value
account_name = key_vault.get_secret("aiName").value  # name of Azure OpenAI resource
api_version = "2024-04-01-preview"  # name of Azure OpenAI resource


default_policy_data = {
    "properties": {
        "basePolicyName": "Microsoft.Default",
        "contentFilters": [
            {
                "name": "hate",
                "blocking": True,
                "enabled": True,
                "allowedContentLevel": "Medium",
                "source": "Prompt",
            },
            {
                "name": "hate",
                "blocking": True,
                "enabled": True,
                "allowedContentLevel": "Medium",
                "source": "Completion",
            },
            {
                "name": "sexual",
                "blocking": True,
                "enabled": True,
                "allowedContentLevel": "Medium",
                "source": "Prompt",
            },
            {
                "name": "sexual",
                "blocking": True,
                "enabled": True,
                "allowedContentLevel": "Medium",
                "source": "Completion",
            },
            {
                "name": "selfharm",
                "blocking": True,
                "enabled": True,
                "allowedContentLevel": "Medium",
                "source": "Prompt",
            },
            {
                "name": "selfharm",
                "blocking": True,
                "enabled": True,
                "allowedContentLevel": "Medium",
                "source": "Completion",
            },
            {
                "name": "violence",
                "blocking": True,
                "enabled": True,
                "allowedContentLevel": "Medium",
                "source": "Prompt",
            },
            {
                "name": "violence",
                "blocking": True,
                "enabled": True,
                "allowedContentLevel": "Medium",
                "source": "Completion",
            },
            {
                "name": "jailbreak",
                "blocking": True,
                "source": "Prompt",
                "enabled": True,
            },
            {
                "name": "indirect_attack",
                "blocking": True,
                "source": "Prompt",
                "enabled": True,
            },
        ],
    }
}


class AOAIContentFilterManager:
    def __init__(self, subscription_id, resource_group_name, account_name):
        self.subscription_id = subscription_id
        self.resource_group_name = resource_group_name
        self.account_name = account_name
        self.api_version = api_version
        self.credential = DefaultAzureCredential()
        self.access_token = self._get_access_token()
        self.default_policy_data = default_policy_data

    def _get_access_token(self):
        token = self.credential.get_token("https://management.azure.com/.default").token
        return token

    def list_content_filters(self):
        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourceGroups/{self.resource_group_name}/providers/Microsoft.CognitiveServices/accounts/{self.account_name}/raiPolicies?api-version={self.api_version}"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            response = response.json()
            filters = [filter["name"] for filter in response["value"]]
            return filters
        else:
            raise Exception(
                f"Failed to retrieve content filters. Status code: {response.status_code}, Response: {response.text}"
            )

    def get_filter_details(self, rai_policy_name):
        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourceGroups/{self.resource_group_name}/providers/Microsoft.CognitiveServices/accounts/{self.account_name}/raiPolicies/{rai_policy_name}?api-version={self.api_version}"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(
                f"Failed to retrieve filter details for {rai_policy_name}. Status code: {response.status_code}, Response: {response.text}"
            )

    def create_or_update_filter(self, rai_policy_name, policy_data=None):
        if policy_data is None:
            policy_data = self.default_policy_data

        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourceGroups/{self.resource_group_name}/providers/Microsoft.CognitiveServices/accounts/{self.account_name}/raiPolicies/{rai_policy_name}?api-version={self.api_version}"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        response = requests.put(url, headers=headers, json=policy_data)
        if response.status_code in [200, 201]:
            return response.json()
        else:
            raise Exception(
                f"Failed to create or update filter for {rai_policy_name}. Status code: {response.status_code}, Response: {response.text}"
            )

    def delete_filter(self, rai_policy_name):

        url = f"https://management.azure.com/subscriptions/{self.subscription_id}/resourceGroups/{self.resource_group_name}/providers/Microsoft.CognitiveServices/accounts/{self.account_name}/raiPolicies/{rai_policy_name}?api-version={self.api_version}"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        response = requests.delete(url, headers=headers)

        if response.status_code == 202:
            return f"Filter {rai_policy_name} successfully deleted."
        elif response.status_code == 204:
            return f"Filter {rai_policy_name} does not exist."
        else:
            raise Exception(
                f"Failed to delete filter for {rai_policy_name}. Status code: {response.status_code}, Response: {response.text}"
            )


cf_manager = AOAIContentFilterManager(
    subscription_id, resource_group_name, account_name
)
filters = cf_manager.list_content_filters()
print("Content Filters:", filters)

# reset filter to default
_ = cf_manager.create_or_update_filter("prompt-shield", default_policy_data)

# # show details of current content filter
# current_policy = cf_manager.get_filter_details('prompt-shield')
# print(current_policy['properties']['contentFilters'])
filters = cf_manager.list_content_filters()

print("Content Filters:", filters)
