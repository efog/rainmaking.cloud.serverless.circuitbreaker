import { Handler } from 'aws-lambda';

export const handler: Handler = async (event, context) => {
    console.log('EVENT: \n' + JSON.stringify(event, null, 2));
    console.log('CONTEXT: \n' + JSON.stringify(context, null, 2));
    return {
        statusCode: 200,
        body: JSON.stringify({"message": "Hello World!"}),
    };
};