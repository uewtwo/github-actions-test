#!/bin/bash
set -ex

PROJECT_NUMBER=${1}
OWNER=${GITHUB_REPOSITORY_OWNER}

if [[ -z "$OWNER" || -z "$PROJECT_NUMBER" ]]; then
  echo "Error: OWNER or PROJECT_NUMBER is not defined."
  exit 1
fi
gh auth status

# リポジトリプロジェクトをチェック
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
}'
project_data=$(gh api graphql -F query="$fetch_project_iteration" \
  -f owner="$OWNER" \
  -F projectNumber="$PROJECT_NUMBER" \
  || echo "")

# プロジェクトデータの確認
echo "Project Data: $project_data"

# プロジェクトが見つからない場合のエラーメッセージ
if [[ -z "$project_data" || "$project_data" == "null" ]]; then
  echo "Error: Could not find ProjectV2 with the number $PROJECT_NUMBER for $OWNER."
  exit 1
fi

# ユーザーまたは組織のプロジェクト情報を取得
project_id=$(echo "$project_data" | jq -r '.user.projectV2.id // .organization.projectV2.id')
iteration_field_id=$(echo "$project_data" | jq -r '.user.projectV2.fields.nodes[0].id // .organization.projectV2.fields.nodes[0].id')

# 最新のイテレーションを取得
iterations=$(echo "$project_data" | jq -r '.user.projectV2.fields.nodes[0].configuration.iterations // .organization.projectV2.fields.nodes[0].configuration.iterations')

# イテレーションが存在しない場合の処理
if [[ -z "$iterations" || "$iterations" == "null" ]]; then
  echo "No iterations found for project $PROJECT_NUMBER."
  exit 1
fi

# 最新のイテレーションを取得
latest_iteration=$(echo "$iterations" | jq -r '.[-1]')
duration=$(echo "$latest_iteration" | jq -r '.duration')
echo 'latest_iteration: '$latest_iteration

# 最新の終了日を取得
latest_end_date=$(echo "$latest_iteration" | jq -r '.startDate') # e.g. 2000-01-01
echo 'latest_end_date: '$latest_end_date

# 次のイテレーションの開始日を計算 (最新の終了日 + 1日)
next_start_date=$(date -d "$latest_end_date + 1 day" +"%Y-%m-%d")
echo "next_start_date: $next_start_date"

# 次のイテレーションの終了日を計算 (次の開始日 + duration)
next_end_date=$(date -d "$next_start_date + $duration days" +"%Y-%m-%d")
echo "next_end_date: $next_end_date"
next_title="Iteration $next_start_date to $next_end_date"

# 新しいイテレーションを追加する Mutation
create_iteration_mutation='
mutation ($projectId: ID!, $fieldId: ID!, $title: String!, $startDate: Date!, $endDate: Date!) {
  updateProjectV2IterationField(input: {
    projectId: $projectId,
    fieldId: $fieldId,
    addIterations: [{
      title: $title,
      startDate: $startDate,
      endDate: $endDate
    }]
  }) {
    projectV2IterationField {
      id
    }
  }
}'

# GraphQL Mutation を実行して新しいイテレーションを追加
gh api graphql -F query="$create_iteration_mutation" \
  -F projectId="$project_id" \
  -F fieldId="$iteration_field_id" \
  -F title="$next_title" \
  -F startDate="$next_start_date" \
  -F endDate="$next_end_date"

echo "New iteration created: $next_title"
