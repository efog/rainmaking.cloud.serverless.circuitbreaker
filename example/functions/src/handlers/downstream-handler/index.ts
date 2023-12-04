import { Handler } from 'aws-lambda';
import * as ssm from "@aws-sdk/client-ssm";

export const handler: Handler = async (event, context) => {
    console.log('EVENT: \n' + JSON.stringify(event, null, 2));
    console.log('CONTEXT: \n' + JSON.stringify(context, null, 2));
    const ssmClient = new ssm.SSMClient({});
    const getParam = await ssmClient.send(new ssm.GetParameterCommand({Name: "serviceState"}));
    if(getParam.Parameter?.Value !== "OK") {
        throw new Error("Service is disabled");
    }
    return {
        statusCode: 200,
        body: JSON.stringify({"serviceState": getParam.Parameter?.Value}),
    };
};