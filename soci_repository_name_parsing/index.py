import os

AWS_ACCOUNT_ID = os.environ.get("AWS_ACCOUNT_ID", "")
AWS_PARTITION = os.environ.get("AWS_PARTITION", "aws")
AWS_REGION = os.environ.get("AWS_REGION", "")


def handler(event, context):
    filters = event["filters"]
    REPO_PREFIX = f"arn:{AWS_PARTITION}:ecr:{AWS_REGION}:{AWS_ACCOUNT_ID}:repository/"
    repository_arns = []
    response = {}

    try:
        repositories = [filter.split(":")[0] for filter in filters]
        for repository in repositories:
            if repository == "*":
                repository_arns = [REPO_PREFIX + "*"]
                break
            repository_arns.append(REPO_PREFIX + repository)
        status = "success"
    except Exception:
        status = "failed"

    response.update({"repository_arns": repository_arns, "status": status})
    return response
