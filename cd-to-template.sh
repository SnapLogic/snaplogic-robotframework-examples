#!/bin/bash
# Source this file to change to the template directory
# Usage: source cd-to-template.sh  OR  . cd-to-template.sh

cd "{{cookiecutter.primary_pipeline_name}}" && pwd
