/// The Swagger 2.0 description of the API, served at `/swagger/doc.json`.
const Map<String, Object?> openApi = {
  "swagger": "2.0",
  "info": {
    "description": "Dart shelf example with Oicana",
    "title": "Oicana example",
    "contact": {},
    "license": {
      "name": "MIT",
      "url":
          "https://github.com/oicana/oicana-example-dart-shelf/blob/main/LICENSE",
    },
    "version": "1.0",
  },
  "paths": {
    "/blobs": {
      "post": {
        "description":
            "Upload a blob (image, file, etc.) to use as template input. Returns a UUID to reference the blob in compilation requests.",
        "consumes": ["multipart/form-data"],
        "produces": ["application/json"],
        "tags": ["blob"],
        "parameters": [
          {
            "type": "file",
            "description": "The file to upload",
            "name": "file",
            "in": "formData",
            "required": true,
          },
        ],
        "responses": {
          "200": {
            "description": "Blob uploaded successfully",
            "schema": {"\$ref": "#/definitions/UploadResponse"},
          },
          "400": {
            "description": "Invalid file upload",
            "schema": {"\$ref": "#/definitions/ErrorResponse"},
          },
          "500": {
            "description": "Failed to save file to disk",
            "schema": {"\$ref": "#/definitions/ErrorResponse"},
          },
        },
      },
    },
    "/certificates": {
      "post": {
        "description": "Create a certificate",
        "consumes": ["application/json"],
        "produces": ["application/pdf"],
        "tags": ["certificates"],
        "parameters": [
          {
            "description": "Certificate details",
            "name": "payload",
            "in": "body",
            "required": true,
            "schema": {"\$ref": "#/definitions/CreateCertificate"},
          },
        ],
        "responses": {
          "200": {
            "description": "The compiled PDF certificate",
            "schema": {"type": "file"},
          },
          "400": {
            "description": "Bad Request",
            "schema": {"\$ref": "#/definitions/ErrorResponse"},
          },
        },
      },
    },
    "/templates": {
      "get": {
        "description": "Get a list of all template IDs known to the service.",
        "produces": ["application/json"],
        "tags": ["template"],
        "responses": {
          "200": {
            "description": "OK",
            "schema": {
              "type": "array",
              "items": {"type": "string"},
            },
          },
        },
      },
    },
    "/templates/{templateID}": {
      "get": {
        "description": "Download a packed template.",
        "produces": ["application/zip"],
        "tags": ["template"],
        "parameters": [
          {
            "type": "string",
            "x-example": "table",
            "description": "The identifier of the template to download.",
            "name": "templateID",
            "in": "path",
            "required": true,
          },
        ],
        "responses": {
          "200": {
            "description": "OK",
            "schema": {"type": "file"},
          },
          "404": {
            "description": "Not Found",
            "schema": {"\$ref": "#/definitions/ErrorResponse"},
          },
        },
      },
    },
    "/templates/{templateID}/compile": {
      "post": {
        "description": "Compile a template with given inputs.",
        "consumes": ["application/json"],
        "produces": ["application/pdf"],
        "tags": ["template"],
        "parameters": [
          {
            "type": "string",
            "x-example": "invoice",
            "description": "The identifier of the template to compile.",
            "name": "templateID",
            "in": "path",
            "required": true,
          },
          {
            "description": "Inputs for template compilation",
            "name": "payload",
            "in": "body",
            "required": true,
            "schema": {"\$ref": "#/definitions/CompilationPayload"},
          },
        ],
        "responses": {
          "200": {
            "description": "OK",
            "schema": {"type": "file"},
          },
          "400": {
            "description": "Bad Request",
            "schema": {"\$ref": "#/definitions/ErrorResponse"},
          },
          "404": {
            "description": "Not Found",
            "schema": {"\$ref": "#/definitions/ErrorResponse"},
          },
        },
      },
    },
    "/templates/{templateID}/preview": {
      "post": {
        "description":
            "Generate a PNG preview of the template with given inputs.",
        "consumes": ["application/json"],
        "produces": ["image/png"],
        "tags": ["template"],
        "parameters": [
          {
            "type": "string",
            "x-example": "invoice",
            "description": "The identifier of the template to preview.",
            "name": "templateID",
            "in": "path",
            "required": true,
          },
          {
            "description": "Inputs for template compilation",
            "name": "payload",
            "in": "body",
            "required": true,
            "schema": {"\$ref": "#/definitions/CompilationPayload"},
          },
        ],
        "responses": {
          "200": {
            "description": "OK",
            "schema": {"type": "file"},
          },
          "400": {
            "description": "Bad Request",
            "schema": {"\$ref": "#/definitions/ErrorResponse"},
          },
          "404": {
            "description": "Not Found",
            "schema": {"\$ref": "#/definitions/ErrorResponse"},
          },
        },
      },
    },
    "/templates/{templateID}/reset": {
      "post": {
        "description":
            "Remove a template from the cache and free it. The template is unavailable until the service restarts.",
        "tags": ["template"],
        "parameters": [
          {
            "type": "string",
            "x-example": "table",
            "description": "The identifier of the template to reset.",
            "name": "templateID",
            "in": "path",
            "required": true,
          },
        ],
        "responses": {
          "204": {"description": "No Content"},
          "404": {"description": "Not Found"},
        },
      },
    },
  },
  "definitions": {
    "BlobInput": {
      "type": "object",
      "properties": {
        "blobId": {
          "description": "UUID of the blob from the blob storage",
          "type": "string",
          "format": "uuid",
          "example": "00000000-0000-0000-0000-000000000000",
        },
        "key": {
          "description": "The input key for the blob",
          "type": "string",
          "example": "banner",
        },
      },
    },
    "CompilationPayload": {
      "type": "object",
      "properties": {
        "blobInputs": {
          "type": "array",
          "items": {"\$ref": "#/definitions/BlobInput"},
        },
        "jsonInputs": {
          "type": "array",
          "items": {"\$ref": "#/definitions/JsonInput"},
        },
      },
      "example": compilationPayloadExample,
    },
    "CreateCertificate": {
      "type": "object",
      "properties": {
        "name": {
          "description": "Name to create the certificate for",
          "type": "string",
          "example": "Jane Doe",
        },
      },
    },
    "ErrorResponse": {
      "type": "object",
      "properties": {
        "message": {"type": "string"},
      },
    },
    "JsonInput": {
      "type": "object",
      "properties": {
        "key": {
          "description": "The input key",
          "type": "string",
          "example": "invoice",
        },
        "value": {
          "description": "Any JSON value, passed to the template as is",
          "type": "object",
        },
      },
    },
    "UploadResponse": {
      "type": "object",
      "properties": {
        "id": {
          "description": "The UUID assigned to the uploaded blob",
          "type": "string",
          "format": "uuid",
          "example": "550e8400-e29b-41d4-a716-446655440000",
        },
      },
    },
  },
  "tags": [
    {
      "description":
          "Template API endpoints. Find used templates at https://github.com/oicana/oicana-example-templates.",
      "name": "template",
    },
    {"description": "Create certificates", "name": "certificates"},
    {
      "description":
          "Blob storage endpoints. Upload files (images, documents) to use as template inputs.",
      "name": "blob",
    },
  ],
  "externalDocs": {
    "description": "General documentation for Oicana.",
    "url": "https://oicana.com/docs/",
  },
};

const compilationPayloadExample = {
  "jsonInputs": [
    {
      "key": "invoice",
      "value": {
        "id": "2025-03-10t172205",
        "issuingDate": "2025-04-27",
        "deliveryDate": "2025-04-19",
        "dueDate": "2025-05-06",
        "biller": {
          "name": "Alex Johnson",
          "title": "Senior Consultant",
          "company": "Example Solutions GmbH",
          "vat-id": "DE1234567",
          "iban": "DE89370400440532013000",
          "address": {
            "country": "Germany",
            "city": "Berlin",
            "postal-code": "10115",
            "street": "Sample Street 23",
          },
        },
        "recipient": {
          "name": "Maria Schmidt",
          "title": "IT Manager",
          "vat-id": "DE7654321",
          "address": {
            "country": "Germany",
            "city": "Munich",
            "postal-code": "80331",
            "street": "Business Avenue 1",
          },
        },
        "items": [
          {
            "date": "2025-04-03",
            "description": "Wireless keyboard",
            "quantity": 4,
            "price": 25,
          },
          {
            "date": "2025-04-03",
            "description": "USB-C cable",
            "quantity": 2,
            "price": 45,
          },
          {
            "date": "2025-04-03",
            "description": "Network infrastructure consultation",
            "dur-min": 120,
            "price": 200,
          },
        ],
      },
    },
  ],
  "blobInputs": [
    {"key": "banner", "blobId": "00000000-0000-0000-0000-000000000000"},
  ],
};
