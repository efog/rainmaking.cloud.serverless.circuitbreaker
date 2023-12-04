/* eslint-disable no-undef */
module.exports = {
    tables: [
        {
            TableName: process.env.LAMBDA_UPSTREAM_SERVICESTABLENAME || "circuitbreaker_services_table",
            KeySchema: [{ AttributeName: 'serviceName', KeyType: 'HASH' }],
            AttributeDefinitions: [{ AttributeName: 'serviceName', AttributeType: 'S' }],
            ProvisionedThroughput: { ReadCapacityUnits: 1, WriteCapacityUnits: 1 },
        }
    ],
};