# PROJECT opas-api

## OpenAPI definition

https://swagger.io/docs/specification/basic-structure/

## Swagger UI

### Running UI in Docker container

https://swagger.io/docs/open-source-tools/swagger-ui/usage/installation/

```bash
docker run -p 9000:8080 -e SWAGGER_JSON=/mnt/openapi.yml -e DOC_EXPANSION="none" -v /PATH/OF/THE/YAML/FILE/DIRECTORY:/mnt swaggerapi/swagger-ui
```
