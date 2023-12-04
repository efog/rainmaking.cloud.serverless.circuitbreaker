import { Context, SNSEvent } from "aws-lambda";
import {
    CreateTableCommand,
    CreateTableCommandInput,
    DeleteTableCommand, 
    DynamoDBClient, 
    DynamoDBClientConfig, 
    GetItemCommand, 
    GetItemCommandInput, 
    GetItemCommandOutput, 
    ListTablesCommand,
    ListTablesCommandInput
} from "@aws-sdk/client-dynamodb";
import { handler } from ".";
import exp = require("constants");

const isTest = process.env.JEST_WORKER_ID;
const circuitBreakerServicesTableName = process.env.LAMBDA_UPSTREAM_SERVICESTABLENAME || 'defaultServicesTable';
const circuitBreakerServiceName = process.env.LAMBDA_UPSTREAM_SERVICENAME || 'defaultService';

const config = {
    convertEmptyValues: true,
    ...(isTest && {
        endpoint: "http://localhost:8000"
    }),
} as DynamoDBClientConfig;
const dynamoDBClient = new DynamoDBClient(config);

async function ensureTable(tableName: string) {
    const commmand = new ListTablesCommand({} as ListTablesCommandInput);
    const tables = await dynamoDBClient.send(commmand);
    if (tables.TableNames?.includes(tableName)) {
        console.log(`Table ${tableName} exists`);
        const deleteTableCommand = new DeleteTableCommand({ TableName: tableName });
        await dynamoDBClient.send(deleteTableCommand);
    }
    const createTableCommand = new CreateTableCommand({
        TableName: tableName,
        AttributeDefinitions: [{ AttributeName: "serviceName", AttributeType: "S" }],
        KeySchema: [{ AttributeName: "serviceName", KeyType: "HASH" }],
        ProvisionedThroughput: { ReadCapacityUnits: 1, WriteCapacityUnits: 1 }
    } as CreateTableCommandInput);
    await dynamoDBClient.send(createTableCommand);
}

async function getServiceCircuitState(tableName: string, serviceName: string): Promise<GetItemCommandOutput> {
    const getItem = new GetItemCommand({
        AttributesToGet: ["isCircuitClosed"],
        Key: {
            serviceName: { S: serviceName },
        },
        TableName: tableName,
    } as GetItemCommandInput);
    return dynamoDBClient.send(getItem);
}

describe("circuit alarm handler", () => {
    beforeAll(async () => {
        console.log(`using DynamoDB Config ${JSON.stringify(config)}`);
        await ensureTable(circuitBreakerServicesTableName);
    });
    it("throws an error with undefined payload", async () => {
        const target = handler;
        const invalidEventPayload = {} as SNSEvent;
        const invalidEventContext = {} as Context;
        await expect(target(invalidEventPayload, invalidEventContext, () => { })).rejects.toThrow(TypeError);
    });
    it("throws an error with invalid event", async () => {
        const target = handler;
        const inAlarmEventPayload = {
            Records: [{
                Sns: {
                    Message: ""
                }
            }]
        } as SNSEvent;
        const eventContext = {} as Context;
        await expect(target(inAlarmEventPayload, eventContext, () => { })).rejects.toThrow(SyntaxError);
    });
    it("handles an ok state alarm sns message", async () => {
        const target = handler;
        const inAlarmEventPayload = {
            Records: [{
                Sns: {
                    Message: JSON.stringify({
                        "version": "0",
                        "id": "c0a7f7b8-9c5e-4f3f-8a8e-e2b9c9f8b9c9",
                        "detail-type": "CloudWatch Alarm State Change",
                        "source": "aws.cloudwatch",
                        "account": "123456789012",
                        "time": "2021-12-15T21:04:36Z",
                        "region": "us-east-1",
                        "resources": [
                            "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                        ],
                        "detail": {
                            "alarmName": "jestTestsServiceCircuitBreaker",
                            "state": {
                                "value": "OK"
                            }
                        }
                    })
                }
            }]
        } as SNSEvent;
        const eventContext = {} as Context;
        await target(inAlarmEventPayload, eventContext, () => { });
        const serviceCircuitState = await getServiceCircuitState(circuitBreakerServicesTableName, circuitBreakerServiceName);
        expect(serviceCircuitState.Item).toBeDefined();
        expect(serviceCircuitState.Item?.isCircuitClosed).toBeDefined();
        expect(serviceCircuitState.Item?.isCircuitClosed.BOOL).toBe(true);
    });
    it("handles an alarm state sns message", async () => {
        const target = handler;
        const inAlarmEventPayload = {
            Records: [{
                Sns: {
                    Message: JSON.stringify({
                        "version": "0",
                        "id": "c0a7f7b8-9c5e-4f3f-8a8e-e2b9c9f8b9c9",
                        "detail-type": "CloudWatch Alarm State Change",
                        "source": "aws.cloudwatch",
                        "account": "123456789012",
                        "time": "2021-12-15T21:04:36Z",
                        "region": "us-east-1",
                        "resources": [
                            "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                        ],
                        "detail": {
                            "alarmName": "jestTestsServiceCircuitBreaker",
                            "state": {
                                "value": "ALARM"
                            }
                        }
                    })
                }
            }]
        } as SNSEvent;
        const eventContext = {} as Context;
        await target(inAlarmEventPayload, eventContext, () => { });
        const serviceCircuitState = await getServiceCircuitState(circuitBreakerServicesTableName, circuitBreakerServiceName);
        expect(serviceCircuitState.Item).toBeDefined();
        expect(serviceCircuitState.Item?.isCircuitClosed).toBeDefined();
        expect(serviceCircuitState.Item?.isCircuitClosed.BOOL).toBe(false);
    });
});
