#!/bin/bash
set -e

OWNER="uewtwo"  # GitHubのユーザーまたは組織名
PROJECT_NUMBER=3        # 検索したいProjectV2の番号

# GraphQL クエリ実行 (エラーが発生しても終了しないようにします)
echo "Running GraphQL query..."
fetch_project_iteration='
query($owner: String!, $projectNumber: Int!) {
  user(login: $owner) {
    projectV2(number: $projectNumber) {
      id
      title
      fields(first: 20) {
        nodes {
          ... on ProjectV2IterationField {
            id
            configuration {
              iterations {
                id
                title
                startDate
                duration
              }
            }
          }
        }
      }
    }
  }
  organization(login: $owner) {
    projectV2(number: $projectNumber) {
      id
      title
      fields(first: 20) {
        nodes {
          ... on ProjectV2IterationField {
            id
            configuration {
              iterations {
                id
                title
                startDate
                duration
              }
            }
          }
        }
      }
    }
  }
}'
project_data=$(gh api graphql -F query="$fetch_project_iteration" \
  -f owner="$OWNER" \
  -F projectNumber="$PROJECT_NUMBER" \
  || echo "")

# GitHub APIレスポンスを表示
echo "Response from GitHub API:"
echo "$project_data"

# user または organization のプロジェクトを取得
user_project=$(echo "$project_data" | jq -r '.data.user.projectV2 // empty')
org_project=$(echo "$project_data" | jq -r '.data.organization.projectV2 // empty')

# user プロジェクトが見つかればそれを表示
if [[ -n "$user_project" ]]; then
  echo "User project: $user_project"
# organization プロジェクトが見つかればそれを表示
elif [[ -n "$org_project" ]]; then
  echo "Organization project: $org_project"
# 両方のプロジェクトが見つからない場合
else
  echo "No ProjectV2 found for the given owner and number."
  exit 1
fi
