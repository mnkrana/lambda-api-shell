echo Welcome to lambda and api creation process!
echo
echo Enter role name:
read roleName
echo
echo Enter function name:
read functionName
echo
echo Enter api name:
read apiName
echo
echo Enter part part! For ex: players, customers etc.
read partPath
echo
echo Enter aws region!
read region
echo
echo "############################################"
echo Building go code...
GOOS=linux GOARCH=arm64 go build -tags lambda.norpc -o bootstrap ./
echo
echo "############################################"
echo Zipping binary...
zip myFunction.zip bootstrap
echo
echo "############################################"
echo Creating role...
roleArn=$(aws iam create-role --role-name $roleName --assume-role-policy-document file://policy.json | jq -r '.Role.Arn')
if [ -z $roleArn ]; then echo "role arn is NULL, exiting"; exit 1; else echo echo Stored rolearn $roleArn; fi
echo
echo "############################################"
echo Attaching role policy basic execution role...
aws iam attach-role-policy --role-name $roleName --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
echo Wait for 5
sleep 5 
echo "############################################"
echo Creating lambda function...
functionArn=$(aws lambda create-function --function-name $functionName --runtime provided.al2023 --role $roleArn --handler bootstrap --zip-file fileb://myfunction.zip --architectures arm64 | jq -r '.FunctionArn')
if [ -z $functionArn ]; then echo "function arn is NULL, exiting..."; exit 1; else echo Stored function arn $functionArn; fi
echo
echo "############################################"
echo Listing all functions!
aws lambda list-functions | grep Name
echo
echo "############################################"
echo Creating api...
apiId=$(aws apigateway create-rest-api --name $apiName --endpoint-configuration types=REGIONAL | jq -r '.id')
if [ -z "$apiId" ]; then echo "NULL"; exit 1; else echo Stored api id $apiId; fi
echo
echo "############################################"
echo Get resource
parentId=$(aws apigateway get-resources --rest-api-id $apiId | jq -r '.items[].id')
if [ -z "$parentId" ]; then echo "NULL"; exit 1; else echo Stored parent id $parentId; fi
echo
echo "############################################"
echo Creating resource...	
resourceId=$(aws apigateway create-resource --rest-api-id $apiId --parent-id $parentId --path-part $partPath | jq -r '.id')
if [ -z "$resourceId" ]; then echo "NULL"; exit 1; else echo Stored resource id $resourceId; fi
echo
echo "############################################"
echo Putting method to the resource...
aws apigateway put-method --rest-api-id $apiId --resource-id $resourceId --http-method ANY --authorization-type NONE
echo
echo "############################################"
echo Get account id!
accountId=$(aws sts get-caller-identity | jq -r '.Account')
if [ -z "$accountId" ]; then echo "NULL"; exit 1; else echo Stored account id $accountId; fi
echo
echo "############################################"
echo Set uri!
uri=arn:aws:apigateway:$region:lambda:path/2015-03-31/functions/arn:aws:lambda:$region:$accountId:function:$functionName/invocations
echo Uri is $uri
echo
echo "############################################"
echo Putting integration...
aws apigateway put-integration --rest-api-id $apiId --resource-id $resourceId --http-method ANY --type AWS_PROXY --integration-http-method POST --uri $uri
echo
echo "############################################"
echo Set source arn!
sourceArn=arn:aws:execute-api:$region:$accountId:$apiId"/*/*/*"
echo Source arn is $sourceArn
echo
echo "############################################"
echo Genrate statement-id:
uuid=$(uuidgen)
echo Statement id is $uuid
echo
echo "############################################"
echo Add permission to the lambda function:	
aws lambda add-permission --profile default --function-name $functionName --statement-id $uuid --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn $sourceArn
echo
echo "############################################"
echo Deploying api...
aws apigateway create-deployment --rest-api-id $apiId --stage-name staging
echo
echo "############################################"
echo Testing api...	
aws apigateway test-invoke-method --rest-api-id $apiId --resource-id $resourceId --http-method "GET"
echo
echo "############################################"
echo Set url:	
url=https://$apiId.execute-api.ap-south-1.amazonaws.com/staging/$partPath
echo Url is $url
echo
echo "############################################"