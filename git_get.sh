#!/usr/bin/env bash

set -e

# Paths
CWD=$(pwd)
TERRAFORM_PATH="${CWD}/terraform-website"

# GITHUB_ACCESS_TOKEN
CURL_PARAMETERS=""
if [[ -n "${GITHUB_ACCESS_TOKEN}" ]]; then
  CURL_PARAMETERS=("-H" "Authorization: token ${GITHUB_ACCESS_TOKEN}")
fi

# Get all repositories
provider_names=()
provider_urls=()
get_repositories() {
  local org=${1}
  shift
  local whitelist=(${@})

  local page=1
  local local_provider_names=()
  local local_provider_urls=()
  while :; do
    local data=$(curl "${CURL_PARAMETERS[@]}" -s "https://api.github.com/orgs/${org}/repos?per_page=100&page=${page}" | jq -r)
    local names=($(echo ${data} | jq -r .[].name))

    local_provider_names+=($(echo ${data} | jq -r ".[] | select(.name | test(\"^terraform-provider\")) | select(.archived | not) | .name"))
    local_provider_urls+=($(echo ${data} | jq -r ".[] | select(.name | test(\"^terraform-provider\")) | select(.archived | not) | .clone_url"))

    # Break
    if [[ ${#names[@]} != 100 ]]; then
      break
    fi

    page=$((page+1))
  done

  # Filter
  if [[ ${#whitelist[@]} == 0 ]]; then
    provider_names+=(${local_provider_names[@]})
    provider_urls+=(${local_provider_urls[@]})
  else
    for i in ${!local_provider_names[@]}; do
      local name=${local_provider_names[$i]}
      local url=${local_provider_urls[$i]}
      for j in ${!whitelist[@]}; do
        local w_name=${whitelist[j]}
        if [[ "${name}" == "terraform-provider-${w_name}" ]]; then
          provider_names+=(${name})
          provider_urls+=(${url})
          break
        fi
      done
    done
  fi
}

echo "Getting repositories"
git clone --depth=1 --shallow-submodules "https://github.com/hashicorp/terraform-website.git" || true
pushd "${TERRAFORM_PATH}"
git clean -fdx
git checkout -- .
git checkout master
git reset --hard origin/master
make sync
popd

get_repositories "hashicorp"
get_repositories "terraform-providers"
get_repositories "cloudflare" "cloudflare"
get_repositories "DataDog" "datadog"
get_repositories "digitalocean" "digitalocean"
get_repositories "fastly" "fastly"
get_repositories "gitlabhq" "gitlab"
get_repositories "grafana" "grafana"
get_repositories "heroku" "heroku"
get_repositories "mongodb" "mongodbatlas"
get_repositories "newrelic" "newrelic"
get_repositories "PagerDuty" "pagerduty"

# Clone
count=${#provider_names[@]}
for i in ${!provider_names[@]}; do
  name=${provider_names[$i]}
  name_only=${name#terraform-provider-}
  git_url=${provider_urls[$i]}
  content_providers_path=${TERRAFORM_PATH}/content/source/docs/providers
  content_layouts_path=${TERRAFORM_PATH}/content/source/layouts
  content_provider_path=${content_providers_path}/${name_only}
  content_layout_path=${TERRAFORM_PATH}/content/source/layouts/${name_only}.erb
  
  ext_providers_path=${TERRAFORM_PATH}/ext/providers
  ext_provider_path=${ext_providers_path}/${name_only}

  echo "Clone $((i+1))/${count} ${name}"
  if [[ -d ${ext_provider_path} ]]; then
    if [[ $(git -C ${ext_provider_path} rev-parse --abbrev-ref HEAD) != "HEAD" ]]; then
      git -C ${ext_provider_path} pull
    fi
  else
    git clone --depth=1 ${git_url} ${ext_provider_path}
  fi

  if [[ ! -L ${content_provider_path} ]]; then
    if [[ -d ${ext_provider_path}/website/docs ]]; then
      ln -s $(realpath ${ext_provider_path}/website/docs --relative-to ${content_providers_path}) ${content_provider_path}
    elif [[ -d ${ext_provider_path}/docs ]]; then
      ln -s $(realpath ${ext_provider_path}/docs --relative-to ${content_providers_path}) ${content_provider_path}
    fi
  fi

  if [[ ! -L ${content_layout_path} ]]; then
    if [[ -f ${ext_provider_path}/website/${name_only}.erb ]]; then
      ln -s $(realpath ${ext_provider_path}/website/${name_only}.erb --relative-to ${content_layouts_path}) ${content_layout_path}
    elif [[ -f ${ext_provider_path}/website/layout.erb ]]; then
      ln -s $(realpath ${ext_provider_path}/website/layout.erb --relative-to ${content_layouts_path}) ${content_layout_path}
    fi
  fi
done

# Fixes
## Remove `layout:` from AWS and Scaffolding docs
if [[ ${OSTYPE} == "linux-gnu"* ]]; then
  find ${TERRAFORM_PATH}/ext/providers/aws/website/docs \( -name "*.markdown" -or -name "*.md" \) -exec sed -e "/layout:/d" -i"" {} \;
  find ${TERRAFORM_PATH}/ext/providers/scaffolding/website/docs \( -name "*.markdown" -or -name "*.md" \) -exec sed -e "/layout:/d" -i"" {} \;
else
  find ${TERRAFORM_PATH}/ext/providers/aws/website/docs \( -name "*.markdown" -or -name "*.md" \) -exec sed -e "/layout:/d" -i "" {} \;
  find ${TERRAFORM_PATH}/ext/providers/scaffolding/website/docs \( -name "*.markdown" -or -name "*.md" \) -exec sed -e "/layout:/d" -i "" {} \;
fi
