zip -r bsc-bot.zip .
aws lambda update-function-code --function-name bsc-deposit --zip-file fileb://bsc-bot.zip
rm bsc-bot.zip
