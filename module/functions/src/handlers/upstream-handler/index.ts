import { Handler } from 'aws-lambda';
import { DynamoDBClient, GetItemCommand } from '@aws-sdk/client-dynamodb';

const dynamodbClient = new DynamoDBClient({});
const circuitBreakerServicesTableName = process.env.LAMBDA_UPSTREAM_SERVICESTABLENAME;

export const handler: Handler = async (event, context) => {
    console.log('EVENT: \n' + JSON.stringify(event, null, 2));
    console.log('CONTEXT: \n' + JSON.stringify(context, null, 2));
    const getServiceCircuitBreakerStatus = await dynamodbClient.send(
        new GetItemCommand({TableName: circuitBreakerServicesTableName, Key: {serviceName: {S: event.serviceName}}})
    );
    console.log('SERVICE CIRCUIT BREAKER STATUS: \n' + JSON.stringify(getServiceCircuitBreakerStatus, null, 2));
    const serviceState = getServiceCircuitBreakerStatus.Item;
    return {
        statusCode: 200,
        body: {"isCircuitClosed": serviceState ? serviceState.isCircuitClosed : {"BOOL": true} },
    };
};