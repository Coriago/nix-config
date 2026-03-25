#!/usr/bin/env bash
while true; do
  kubectl exec -it postgres-0 -n longhorn-test -- psql -U postgres -c "SELECT * FROM test;"
  sleep 2
done