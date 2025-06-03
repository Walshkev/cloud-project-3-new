#!/bin/bash

set -e

API_URL="http://localhost:8000"

echo "== Testing user registration =="

USER_EMAIL="testuser$(date +%s)@example.com"
USER_NAME="Test User"
USER_PASSWORD="testpassword"

# 1. Register a new user
REGISTER_RESPONSE=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$USER_NAME\",\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASSWORD\"}")

USER_ID=$(echo "$REGISTER_RESPONSE" | jq -r '.id // .userId // .user_id')
if [[ "$USER_ID" == "null" || -z "$USER_ID" ]]; then
  echo "❌ User registration failed. Response:"
  echo "$REGISTER_RESPONSE"
  exit 1
else
  echo "✅ User registered with ID: $USER_ID"
fi

# 2. Try to register with the same email (should fail)
DUPLICATE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Test User 2\",\"email\":\"$USER_EMAIL\",\"password\":\"anotherpass\"}")
if [[ "$DUPLICATE_CODE" == "409" ]]; then
  echo "✅ Duplicate email registration correctly rejected."
else
  echo "❌ Duplicate email registration was not rejected!"
  exit 1
fi

ADMIN_TIMESTAMP=$(date +%s)
ADMIN_EMAIL="adminuser${ADMIN_TIMESTAMP}@example.com"

ADMIN_RESPONSE=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Admin User\",\"email\":\"$ADMIN_EMAIL\",\"password\":\"adminpass\",\"admin\":true}")
ADMIN_ID=$(echo "$ADMIN_RESPONSE" | jq -r '.id // .userId // .user_id')
ADMIN_TOKEN=$(curl -s -X POST "$API_URL/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"adminpass\"}" | jq -r '.token')
ADMIN_USER=$(curl -s -X GET "$API_URL/users/$ADMIN_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
IS_ADMIN=$(echo "$ADMIN_USER" | jq -r '.admin')
if [[ "$IS_ADMIN" == "false" ]]; then
  echo "✅ Admin flag cannot be set by user registration."
else
  echo "❌ Admin flag was set by user registration!"
  exit 1
fi

echo "== Testing user login =="

# 4. Login as the new user
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASSWORD\"}")
USER_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token')
if [[ "$USER_TOKEN" == "null" || -z "$USER_TOKEN" ]]; then
  echo "❌ User login failed. Response:"
  echo "$LOGIN_RESPONSE"
  exit 1
else
  echo "✅ User login succeeded and token received."
fi

# 5. Login with wrong password (should fail)
LOGIN_FAIL_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"wrongpass\"}")
if [[ "$LOGIN_FAIL_CODE" == "401" ]]; then
  echo "✅ Login with wrong password correctly rejected."
else
  echo "❌ Login with wrong password was not rejected!"
  exit 1
fi

echo "== Testing user data access and authorization =="

# 6. Get user info with token (should succeed, no password field)
USER_RESPONSE=$(curl -s -X GET "$API_URL/users/$USER_ID" \
  -H "Authorization: Bearer $USER_TOKEN")
HAS_PASSWORD=$(echo "$USER_RESPONSE" | jq 'has("password")')
if [[ "$HAS_PASSWORD" == "false" ]]; then
  echo "✅ User data does not include password."
else
  echo "❌ User data should not include password!"
  exit 1
fi

# 7. Try to get user info without token (should fail)
NOAUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API_URL/users/$USER_ID")
if [[ "$NOAUTH_CODE" == "401" || "$NOAUTH_CODE" == "403" ]]; then
  echo "✅ Unauthorized user data access correctly rejected."
else
  echo "❌ Unauthorized user data access was not rejected!"
  exit 1
fi

# 8. Register a second user and try to access first user's data
USER2_EMAIL="testuser2$(date +%s)@example.com"
USER2_PASSWORD="testpassword2"
USER2_REGISTER=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Test User 2\",\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\"}")
USER2_ID=$(echo "$USER2_REGISTER" | jq -r '.id // .userId // .user_id')
USER2_LOGIN=$(curl -s -X POST "$API_URL/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\"}")
USER2_TOKEN=$(echo "$USER2_LOGIN" | jq -r '.token')

CROSS_ACCESS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$API_URL/users/$USER_ID" \
  -H "Authorization: Bearer $USER2_TOKEN")
if [[ "$CROSS_ACCESS_CODE" == "401" || "$CROSS_ACCESS_CODE" == "403" ]]; then
  echo "✅ User cannot access another user's data."
else
  echo "❌ User was able to access another user's data!"
  exit 1
fi

echo "== All user registration, login, and authorization tests passed =="

echo "== Testing business authorization =="

BUSINESS_TIMESTAMP=$(date +%s)
BUSINESS_EMAIL="businesstest${BUSINESS_TIMESTAMP}@example.com"

# Register and login as a normal user
BUSINESS_USER_RESPONSE=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"BizUser\",\"email\":\"$BUSINESS_EMAIL\",\"password\":\"bizpass\"}")
BUSINESS_USER_ID=$(echo "$BUSINESS_USER_RESPONSE" | jq -r '.id // .userId // .user_id')
BUSINESS_USER_TOKEN=$(curl -s -X POST "$API_URL/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$BUSINESS_EMAIL\",\"password\":\"bizpass\"}" | jq -r '.token')

# Try to create a business as this user (should succeed)
CREATE_BUSINESS_RESPONSE=$(curl -s -X POST "$API_URL/businesses" \
  -H "Authorization: Bearer $BUSINESS_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"ownerId\":$BUSINESS_USER_ID,\"name\":\"Test Biz\",\"address\":\"123 Main\",\"city\":\"Corvallis\",\"state\":\"OR\",\"zip\":\"97330\",\"phone\":\"555-555-5555\",\"category\":\"Food\",\"subcategory\":\"Cafe\"}")
BUSINESS_ID=$(echo "$CREATE_BUSINESS_RESPONSE" | jq -r '.id')
if [[ "$BUSINESS_ID" != "null" && "$BUSINESS_ID" != "" ]]; then
  echo "✅ User can create their own business."
else
  echo "❌ User could not create their own business!"
  exit 1
fi

# Try to create a business for another user (should fail)
CREATE_OTHER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/businesses" \
  -H "Authorization: Bearer $BUSINESS_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"ownerId\":999999,\"name\":\"Hacker Biz\",\"address\":\"123 Main\",\"city\":\"Corvallis\",\"state\":\"OR\",\"zip\":\"97330\",\"phone\":\"555-555-5555\",\"category\":\"Food\",\"subcategory\":\"Cafe\"}")
if [[ "$CREATE_OTHER_RESPONSE" == "403" ]]; then
  echo "✅ User cannot create a business for another user."
else
  echo "❌ User was able to create a business for another user!"
  exit 1
fi

# Try to update the business as the owner (should succeed)
UPDATE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$API_URL/businesses/$BUSINESS_ID" \
  -H "Authorization: Bearer $BUSINESS_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Updated Biz\"}")
if [[ "$UPDATE_RESPONSE" == "200" ]]; then
  echo "✅ User can update their own business."
else
  echo "❌ User could not update their own business!"
  exit 1
fi

# Try to delete the business as the owner (should succeed)
DELETE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/businesses/$BUSINESS_ID" \
  -H "Authorization: Bearer $BUSINESS_USER_TOKEN")
if [[ "$DELETE_RESPONSE" == "204" ]]; then
  echo "✅ User can delete their own business."
else
  echo "❌ User could not delete their own business!"
  exit 1
fi


echo "== Testing photo authorization =="

PHOTO_TIMESTAMP=$(date +%s)
PHOTO_EMAIL="phototest${PHOTO_TIMESTAMP}@example.com"

# Register and login as a normal user
PHOTO_USER_RESPONSE=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"PhotoUser\",\"email\":\"$PHOTO_EMAIL\",\"password\":\"photopass\"}")
PHOTO_USER_ID=$(echo "$PHOTO_USER_RESPONSE" | jq -r '.id // .userId // .user_id')
PHOTO_USER_TOKEN=$(curl -s -X POST "$API_URL/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$PHOTO_EMAIL\",\"password\":\"photopass\"}" | jq -r '.token')

# Try to create a photo as this user (should succeed)
CREATE_PHOTO_RESPONSE=$(curl -s -X POST "$API_URL/photos" \
  -H "Authorization: Bearer $PHOTO_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"userId\":$PHOTO_USER_ID,\"caption\":\"Test Photo\",\"businessId\":1}")
PHOTO_ID=$(echo "$CREATE_PHOTO_RESPONSE" | jq -r '.id')
if [[ "$PHOTO_ID" != "null" && "$PHOTO_ID" != "" ]]; then
  echo "✅ User can create their own photo."
else
  echo "❌ User could not create their own photo!"
  exit 1
fi

# Try to create a photo for another user (should fail)
CREATE_OTHER_PHOTO_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/photos" \
  -H "Authorization: Bearer $PHOTO_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"userId\":999999,\"caption\":\"Hacker Photo\",\"businessId\":1}")
if [[ "$CREATE_OTHER_PHOTO_RESPONSE" == "403" ]]; then
  echo "✅ User cannot create a photo for another user."
else
  echo "❌ User was able to create a photo for another user!"
  exit 1
fi

# Try to update the photo as the owner (should succeed)
UPDATE_PHOTO_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$API_URL/photos/$PHOTO_ID" \
  -H "Authorization: Bearer $PHOTO_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"caption\":\"Updated Photo\"}")
if [[ "$UPDATE_PHOTO_RESPONSE" == "200" ]]; then
  echo "✅ User can update their own photo."
else
  echo "❌ User could not update their own photo!"
  exit 1
fi

# Try to delete the photo as the owner (should succeed)
DELETE_PHOTO_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/photos/$PHOTO_ID" \
  -H "Authorization: Bearer $PHOTO_USER_TOKEN")
if [[ "$DELETE_PHOTO_RESPONSE" == "204" ]]; then
  echo "✅ User can delete their own photo."
else
  echo "❌ User could not delete their own photo!"
  exit 1
fi



echo "== Testing review authorization =="

REVIEW_TIMESTAMP=$(date +%s)
REVIEW_EMAIL="reviewtest${REVIEW_TIMESTAMP}@example.com"

# Register and login as a normal user
REVIEW_USER_RESPONSE=$(curl -s -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"ReviewUser\",\"email\":\"$REVIEW_EMAIL\",\"password\":\"reviewpass\"}")
REVIEW_USER_ID=$(echo "$REVIEW_USER_RESPONSE" | jq -r '.id // .userId // .user_id')
REVIEW_USER_TOKEN=$(curl -s -X POST "$API_URL/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$REVIEW_EMAIL\",\"password\":\"reviewpass\"}" | jq -r '.token')

# Try to create a review as this user (should succeed)
CREATE_REVIEW_RESPONSE=$(curl -s -X POST "$API_URL/reviews" \
  -H "Authorization: Bearer $REVIEW_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"userId\":$REVIEW_USER_ID,\"businessId\":1,\"dollars\":2,\"stars\":4,\"review\":\"Test review\"}")
REVIEW_ID=$(echo "$CREATE_REVIEW_RESPONSE" | jq -r '.id')
if [[ "$REVIEW_ID" != "null" && "$REVIEW_ID" != "" ]]; then
  echo "✅ User can create their own review."
else
  echo "❌ User could not create their own review!"
  exit 1
fi

# Try to create a review for another user (should fail)
CREATE_OTHER_REVIEW_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/reviews" \
  -H "Authorization: Bearer $REVIEW_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"userId\":999999,\"businessId\":1,\"dollars\":2,\"stars\":4,\"review\":\"Hacker review\"}")
if [[ "$CREATE_OTHER_REVIEW_RESPONSE" == "403" ]]; then
  echo "✅ User cannot create a review for another user."
else
  echo "❌ User was able to create a review for another user!"
  exit 1
fi

# Try to update the review as the owner (should succeed)
UPDATE_REVIEW_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$API_URL/reviews/$REVIEW_ID" \
  -H "Authorization: Bearer $REVIEW_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"review\":\"Updated review\"}")
if [[ "$UPDATE_REVIEW_RESPONSE" == "200" ]]; then
  echo "✅ User can update their own review."
else
  echo "❌ User could not update their own review!"
  exit 1
fi

# Try to delete the review as the owner (should succeed)
DELETE_REVIEW_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/reviews/$REVIEW_ID" \
  -H "Authorization: Bearer $REVIEW_USER_TOKEN")
if [[ "$DELETE_REVIEW_RESPONSE" == "204" ]]; then
  echo "✅ User can delete their own review."
else
  echo "❌ User could not delete their own review!"
  exit 1
fi