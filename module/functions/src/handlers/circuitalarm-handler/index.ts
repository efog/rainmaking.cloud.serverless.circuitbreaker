import { Context, EventBridgeEvent, SNSEvent, SNSHandler } from 'aws-lambda';
import { DynamoDBClient, DynamoDBClientConfig, PutItemCommand, PutItemCommandInput } from '@aws-sdk/client-dynamodb';
import { PutEventsCommand, PutEventsCommandInput } from '@aws-sdk/client-eventbridge';

const isTest = process.env.JEST_WORKER_ID;
const config = {
    convertEmptyValues: true,
    ...(isTest && {
        endpoint: "http://localhost:8000"
    }),
} as DynamoDBClientConfig;
const dynamoDBClient = new DynamoDBClient(config);

const circuitBreakerServicesTableName = process.env.LAMBDA_UPSTREAM_SERVICESTABLENAME || 'defaultServicesTable';
const circuitBreakerServiceName = process.env.LAMBDA_UPSTREAM_SERVICENAME || 'defaultService';

export const handler: SNSHandler = async (event: SNSEvent, context: Context) => {
    console.log('EVENT: \n' + JSON.stringify(event, null, 2));
    console.log('CONTEXT: \n' + JSON.stringify(context, null, 2));
    console.log('ENV: \n' + JSON.stringify(process.env, null, 2));
    for (const record of event.Records) {
        const message = JSON.parse(record.Sns.Message);
        if (message) {
            const inAlarm = message.NewStateValue === "ALARM";
            const item = {
                TableName: circuitBreakerServicesTableName,
                Item: {
                    "serviceName": { "S": circuitBreakerServiceName },
                    "isCircuitClosed": { "BOOL": !inAlarm }
                }
            } as PutItemCommandInput;
            console.log('PUTTING ITEM: \n' + JSON.stringify(item, null, 2));
            await dynamoDBClient.send(
                new PutItemCommand(item)
            );
        }
    }
};