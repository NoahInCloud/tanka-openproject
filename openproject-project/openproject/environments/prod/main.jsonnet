local lib = import '../../../lib/openproject.libsonnet';

lib {
  config+:: {
    namespace: 'lhw-openproject-prod',
    replicas: 2,
    environment: 'production',
  },
  
  deployment: $.openproject.deployment,
  service: $.openproject.service,
}
