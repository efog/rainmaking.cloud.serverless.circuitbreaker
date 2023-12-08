# Implement a Circuit Breaker for AWS Lambda Functions

Micro services are bound with challenges. Being by nature loosely coupled,  they are, for example, require specific error handling patterns and the circuit breaker is one of them. 

What is provided here is a usable implementation of the circuit breaker pattern using Terraform, Amazon StepFunction, AWS Lambda, Amazon DynamoDB and Amazon EventBridge.

## The Circuit Breaker Pattern

The circuit breaker pattern is a failure isolation mechanism. During maintenance, network outages or transient downtime it might be wiser to rapidly fail instead of spending on useless cycles. A good example is payment handling on transactional websites. These often rely on external payment services and when transacgtions are bound to fail because of uncontrolled circumstances, it's just better for a customer to be told quickly that a payment can't be processed than leaving them in the dark for a minute. Properly applied this pattern prevents unnecessary requests and processing thus saving on time, resources, and frustration.

## Understanding the Pattern

Simply explained, the pattern can be implemented as a state machine which checks the state of the circuit before routing to downstream service:

![medium](https://assets.rainmaking.cloud/images/circuit-breaker-hl-diagram-1-1.png "request processing state machine flow diagram")

A key to the pattern is proper health monitoring of the aforementionned downstream service and circuit state management:

![medium](https://assets.rainmaking.cloud/images/circuit-breaker-hl-diagram-2-3.png "healthcheck flow diagram")

## Implementing the Pattern

The requirements behind this module implementing the circuit breaker pattern are the following:

- Use managed and serverless services.
- Support bring your own downstream and healthcheck functions.
- Provide flexibility for alerting and monitoring.

The idea here is to wrap a service caller inside a state machine. The state machine orchestrates a sequence of steps which leads, or not, to the completion of a request. The service caller is injected into the module and it is considered the "expensive" part to protect. Provided with the service caller is a healthcheck which is triggered at pre-defined interval. This schedule trigger has the advantage that it can pre-emptively force an open or a closure of the circuit. Finally the module's implementation relies on a table to keep track of each circuit's state.

### High Level View

![medium](https://assets.rainmaking.cloud/images/circuit-breaker-functional-diagram-1-2.png "high level components diagram")

### Components View

![medium](https://assets.rainmaking.cloud/images/circuit-breaker-components-diagram-1-3.png "AWS components diagram")

### Step Function State Machine View

![medium](https://assets.rainmaking.cloud/images/circuit-breaker-statemachine-diagram-1-1.png "State machine diagram")

### Nuts and Bolts

#### Downstream Function

Provided by the module consumer, it is the service caller. The downstream Lambda Function is wrapped inside the state machine by the module. The downstream function must always throw when in error. This Lambda Function is monitored by Amazon Cloudwatch. Module consumer can define thresholds.

#### Upstream Function

Provided with the module, it reads the circuit state from the database and returns the value to the step function. The state machine decides if it proceeds or not to the invocation of the downstream function.

#### Alarm Handler Function

Provided with the module, the alarm handler subscribes to the Service Monitoring SNS Topic and upon notification updates the circuit states DynamoDB table.

#### Healthcheck Function

Provided by the module's consumer, this function monitors the health of the downstream function. If the downstream function becomes unhealty an error should be thrown. The healthcheck function must always throw when in error and it is monitored by Amazon Cloudwatch. Module consumer can define thresholds.

#### Service Monitoring SNS Topic

Receives Amazon Cloudwatch alarm events and forwards them to subscriptions, in this case the Alarm Handling function.

### Using the Module

The module comes with its pre-built Lambda Functions for the upstream and circuit alarm handling. The module's consumer needs to provide:

- Downstream and Healthcheck Lambda Functions
- Circuit State management Amazon DynamoDB table

#### Building the Lambda Functions

Head to the [functions folder](functions) of the module and launch the *build.sh* script. The module uses the NodeJS 18 runtime.

#### Module Configuration

The module has these key variables that require configuration:

- *circuitbreakable_service_name*

    The name of the service that is circuit breaking enabled.

- *downstream_lambda_function*

    The downstream AWS Lambda Function which is the target of the circuit breaker module.

- *healthcheck_lambda_function*

    The healthchecking AWS Lambda function.

- *downstream_monitoring_configuration* and *healthcheck_monitoring_configuration*

    Configures healthcheck and downstream functions monitoring settings.

## Not So Frequently Asked Questions

1. Does it support AWS Lambda Function versioning?

    No, not yet. I'm still trying to iron this one out...

1. Is resource tagging enabled?

    No, it's on the wanted list.

## How Much Does it Cost?


## Lessons Learned