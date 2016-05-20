#!/bin/bash -x

: ${BLUEFLOOD_QUERY_URL="http://localhost:20000"}
: ${TENANT_ID="123"}

exec 2>&1
exec 1>/tmp/bash-debug.log
apt-get update -y --force-yes

if [[ -z "$RAX_USERNAME" ]] ||  [[ -z "$RAX_APIKEY" ]]
then
cat > /etc/graphite-api.yaml << EOL
search_index: /dev/null
finders:
  - blueflood.TenantBluefloodFinder
functions:
  - graphite_api.functions.SeriesFunctions
  - graphite_api.functions.PieFunctions
time_zone: UTC
blueflood:
  tenant: $TENANT_ID
  urls:
    - $BLUEFLOOD_QUERY_URL
EOL
else
cat > /etc/graphite-api.yaml << EOL
search_index: /dev/null
finders:
  - blueflood.TenantBluefloodFinder
functions:
  - graphite_api.functions.SeriesFunctions
  - graphite_api.functions.PieFunctions
time_zone: UTC
blueflood:
  tenant: $TENANT_ID
  username: $RAX_USERNAME             
  apikey: $RAX_APIKEY                     
  authentication_module: rax_auth
  authentication_class: BluefloodAuth
  urls:
    - $BLUEFLOOD_QUERY_URL
EOL
fi

exec gunicorn -b 0.0.0.0:8888 --access-logfile /var/log/gunicorn-access.log --error-logfile /var/log/gunicorn-error.log -w 8 graphite_api.app:app &

: "${GF_PATHS_DATA:=/var/lib/grafana}"
: "${GF_PATHS_LOGS:=/var/log/grafana}"
: "${GF_PATHS_PLUGINS:=/var/lib/grafana/plugins}"

chown -R grafana:grafana "$GF_PATHS_DATA" "$GF_PATHS_LOGS"
chown -R grafana:grafana /etc/grafana

git clone https://github.com/rackerlabs/blueflood-grafana-graphite_api-plugin.git /var/lib/grafana/plugins

exec gosu grafana /usr/sbin/grafana-server  \
  --homepath=/usr/share/grafana             \
  --config=/etc/grafana/grafana.ini         \
  cfg:default.paths.data="$GF_PATHS_DATA"   \
  cfg:default.paths.logs="$GF_PATHS_LOGS"   \
  cfg:default.paths.plugins="$GF_PATHS_PLUGINS"
