#!/bin/bash
set -e

# Inputs
GITHUB_TOKEN=$1

# Load GitHub event data
EVENT=$(cat "$GITHUB_EVENT_PATH")
REPO=$(echo "$EVENT" | jq -r '.repository.full_name')

PR_NUMBER=$(echo "$EVENT" | jq -r '.pull_request.number')
BASE_BRANCH=$(echo "$EVENT" | jq -r '.pull_request.base.ref')

echo "Base branch: $BASE_BRANCH"
echo "PR number: $PR_NUMBER"

git config --global --add safe.directory "$GITHUB_WORKSPACE"
git fetch origin "$BASE_BRANCH"

echo "Running composer-diff against $BASE_BRANCH..."
composer diff --base=origin/"$BASE_BRANCH":src/composer.lock --target=src/composer.lock \
  --with-platform --with-links --no-interaction > composer-diff.txt

COMMENT_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments" | \
        jq -r ".[] | select(.body | startswith(\"### Composer diff against \")) | .id")

if [[ ! -s composer-diff.txt ]]; then
    echo "Composer diff is empty."

    if [[ -n "$COMMENT_ID" ]]; then
        curl -s -X DELETE -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$REPO/issues/comments/$COMMENT_ID"
        echo "Deleted existing comment."
    fi
else
    echo "Composer diff found:"
    cat composer-diff.txt

    COMMENT_BODY=$(echo -e "### Composer diff against $BASE_BRANCH\n\n$(cat composer-diff.txt)")

    if [[ -n "$COMMENT_ID" ]]; then
        curl -s -X PATCH -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg body "$COMMENT_BODY" '{"body": $body}')" \
            "https://api.github.com/repos/$REPO/issues/comments/$COMMENT_ID"
        echo "Updated existing comment."
    else
        curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg body "$COMMENT_BODY" '{"body": $body}')" \
            "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/comments"
        echo "Created a new comment."
    fi
fi
