zip -r bots.zip .
aws lambda update-function-code --function-name bnbx-bots --zip-file fileb://bots.zip
rm bots.zip
