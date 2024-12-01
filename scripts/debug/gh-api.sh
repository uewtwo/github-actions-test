#!/bin/bash
set -e

OWNER="uewtwo"  # GitHubのユーザーまたは組織名
PROJECT_NUMBER=3        # 検索したいProjectV2の番号


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
project_id=$(echo "$project_data" \
  | jq -r '.data.user // .data.organization' \
  | jq -r '.projectV2.id')
iteration_field_id=$(echo "$project_data" \
  | jq -r '.data.user // .data.organization' \
  | jq -r '.projectV2.fields.nodes[].id | select (.!=null)')
echo 'project_id: '$project_id
echo 'iteration_field_id: '$iteration_field_id
# 最新のイテレーションを取得
iterations=$(echo "$project_data" \
  | jq -r '.data.user // .data.organization' \
  | jq -r '.projectV2.fields.nodes[].configuration | select(.!=null).iterations')

# イテレーションが存在しない場合の処理
if [[ -z "$iterations" || "$iterations" == "null" ]]; then
  echo "No iterations found for project $PROJECT_NUMBER."
  exit 1
fi

# For BDS
# 最新のイテレーションを取得
latest_iteration=$(echo "$iterations" | jq -r '.[-1]')
duration=$(echo "$latest_iteration" | jq -r '.duration')
echo 'latest_iteration: '$latest_iteration
# 最新の終了日を取得
latest_end_date=$(echo "$latest_iteration" | jq -r '.startDate') # e.g. 2000-01-01
echo 'latest_end_date: '$latest_end_date

# 次のイテレーションの開始日を計算 (最新の終了日 + 1日)
next_start_date=$(date -j -v+1d -f "%Y-%m-%d" "$latest_end_date" +%Y-%m-%d)
echo "next_start_date: $next_start_date"

# 次のイテレーションの終了日を計算 (次の開始日 + duration)
next_end_date=$(date -j -v+${duration}d -f "%Y-%m-%d" "$next_start_date" +%Y-%m-%d)
echo "next_end_date: $next_end_date"
