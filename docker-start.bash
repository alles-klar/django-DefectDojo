#!/usr/bin/env bash

function help() {
    echo ""
    echo "$0 usage:"
    echo "  -s                      Start Dojo Container"
    echo "  -c                      Start Celery"
    echo "  -i                      Init Database"
    echo ""
}

function celery_start() {
    celery -A dojo worker -l info --concurrency 3 &
    celery beat -A dojo -l info
}

function makemigrations() {
    echo "Running makemigrations"
    python manage.py makemigrations dojo
    python manage.py makemigrations --merge --noinput
}

function migrate() {
    echo "Running migrate"
    python manage.py migrate
}

function docker_start() {
    echo "Install watson"
    python manage.py installwatson
    python manage.py buildwatson

    python manage.py collectstatic --noinput -v 0
    gunicorn --bind 0.0.0.0:8000 wsgi
}

function create_superuser() {
    echo "Creating superuser"
    python manage.py createsuperuser --noinput --username="$ADMIN_USER" --email="$ADMIN_EMAIL"
    entrypoint_scripts/common/setup-superuser.expect "$ADMIN_USER" "$ADMIN_PASS"
}

function load_data() {
    echo "Load data"
    python manage.py loaddata product_type
    python manage.py loaddata test_type
    python manage.py loaddata development_environment
    python manage.py loaddata system_settings
    python manage.py loaddata benchmark_type
    python manage.py loaddata benchmark_category
    python manage.py loaddata benchmark_requirement
    python manage.py loaddata language_type
    python manage.py loaddata objects_review
    python manage.py loaddata regulation
}

# Make sure setup.bash is run from the same directory it is located in
cd "${0%/*}" || exit  # same as `cd "$(dirname "$0")"` without relying on dirname
# shellcheck disable=SC2034
REPO_BASE="$(pwd)"
# shellcheck disable=SC1091
source entrypoint_scripts/common/config-vars.sh
# shellcheck disable=SC1091
source entrypoint_scripts/os/linux.sh

while getopts 'hr:sr:ir:cr' opt; do
    case $opt in
        h)
            help
            exit 0
            ;;
        s)
            create_dojo_settings
            makemigrations
            docker_start
            ;;
        c)
            create_dojo_settings
            makemigrations
            celery_start
            ;;
        i)
            create_dojo_settings
            makemigrations
            migrate
            create_superuser
            load_data
            #docker_start
            ;;
        ?)
            help
            exit 1
            ;;
    esac
done