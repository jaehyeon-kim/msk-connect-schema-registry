# MSK Connect with External Schema Registry

Use External Schema Registry with MSK Connect

- [Part 1 Local Development](https://jaehyeon.me/blog/2022-03-07-schema-registry-part1/)
  - In this post, we discussed an improved architecture of a Change Data Capture (CDC) solution with a schema registry. A local development environment is set up using Docker Compose. The Debezium and Confluent S3 connectors are deployed with the Confluent Avro converter and the Apicurio registry is used as the schema registry service. A quick example is shown to illustrate how schema evolution can be managed by the schema registry. In the next post, it’ll be deployed to AWS mainly using MSK Connect, Aurora PostgreSQL and ECS.
- [Part 2 MSK Deployment](https://jaehyeon.me/blog/2022-04-03-schema-registry-part2/)
  - In this post, we continued the discussion of a Change Data Capture (CDC) solution with a schema registry and it is deployed to AWS. Multiple services including MSK, MSK Connect, Aurora PostgreSQL and ECS are used to build the solution. All major resources are deployed in private subnets and VPN is used to access them in order to improve developer experience. The Apicurio registry is used as the schema registry service and it is deployed as an ECS service. In order for the connectors to have access to the registry, the Confluent Avro Converter is packaged together with the connector sources. The post ends with illustrating how schema evolution is managed by the schema registry.

![architecture](https://cevo.com.au/wp-content/uploads/2022/02/architecture-2.png)

## Note

If you see the following error, change `user_data_base64` into `user_data`.

```
╷
│ Error: Unsupported argument
│ 
│   on vpn.tf line 22, in module "vpn":
│   22:   user_data_base64 = base64encode(join("\n", [
│ 
│ An argument named "user_data_base64" is not expected here.
╵
```
