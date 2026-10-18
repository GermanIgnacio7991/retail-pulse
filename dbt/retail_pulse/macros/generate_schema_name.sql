{#
  Por defecto dbt crea "retail_pulse_staging". Con esta macro los datasets
  quedan limpios: "staging" y "marts".
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
