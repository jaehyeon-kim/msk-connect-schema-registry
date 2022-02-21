[
  {
    "name": "registry",
    "image": "${container_image}",
    "cpu": ${fargate_cpu},
    "memory": ${fargate_memory},
    "networkMode": "awsvpc",
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${log_group_name}",
          "awslogs-region": "${aws_region}",
          "awslogs-stream-prefix": "registry"
        }
    },
    "portMappings": [
      {
        "containerPort": ${container_port},
        "hostPort": ${host_port}
      }
    ],
    "environment": [
      {
        "name": "APP_ENV",
        "value": "${app_env}"
      },
      {
        "name": "REGISTRY_DATASOURCE_URL",
        "value": "${data_source_url}"
      },
      {
        "name": "REGISTRY_DATASOURCE_USERNAME",
        "value": "${data_source_username}"
      },
      {
        "name": "REGISTRY_DATASOURCE_PASSWORD",
        "value": "${data_source_password}"
      }
    ]
  }
]