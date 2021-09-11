#!/bin/zsh

sft(){
app_host=${3-"http://localhost:4000"} 
app_type=${2-"admin"}
app_token=$1
env="REACT_APP_API_HOST=$app_host
REACT_APP_ACCESS_TOKEN=$app_token
REACT_APP_REFRESH_TOKEN=$app_token
REACT_APP_APPSTORE_LINK=https://itunes.apple.com/gb/app/prosapient-messenger/id1451413831?mt=8
REACT_APP_WS_PROTO_VERSION=0.0.1
EXTEND_ESLINT=true
REACT_APP_SENTRY_DSN=
REACT_APP_TYPE=$app_type
REACT_APP_METRICS_FEATURE=
UPLOADCARE_PUBLIC_KEY=
SURVEY_RESULTS_GUIDE_URL=
REACT_APP_IP_API_URL=http://ip-api.com/json"

  # sed -i -e 's/REACT_APP_ACCESS_TOKEN=/REACT_APP_ACCESS_TOKEN=$1/g' $HOME/Desktop/prosapient/platform-frontend/.env

echo $env > $HOME/Desktop/prosapient/platform-frontend/.env
}
