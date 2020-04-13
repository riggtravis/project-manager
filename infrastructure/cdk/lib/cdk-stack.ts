import * as cdk from "@aws-cdk/core";
import {
  ManagedPolicy,
  PolicyDocument,
  PolicyStatement,
  Effect,
} from "@aws-cdk/aws-iam";

export class ManagedPolicyStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // The code that defines your stack goes here
    new ManagedPolicy(this, "ContinuousIntegrationPolicy", {
      managedPolicyName: "ContinuousIntegrationPolicy",
      description: "A managed policy for continuous integration tools",
      path: "/tools/",
      document: new PolicyDocument({
        assignSids: true,
        statements: [
          new PolicyStatement({
            effect: Effect.ALLOW,
            actions: [
              "sts:*",
              "s3:*",
              "ec2:*",
              "cloud9:*",
              "iam:*",
              "kms:*",
            ],
            resources: [
              "*"
            ]
          }),
        ],
      }),
    });
  }
}
