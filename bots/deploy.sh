zip -r bots.zip .
aws lambda update-function-code --function-name bsc-deposit --zip-file fileb://bots.zip
rm bots.zip
