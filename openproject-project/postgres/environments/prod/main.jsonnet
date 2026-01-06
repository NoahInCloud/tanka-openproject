local lib = import '../../../lib/openproject.libsonnet';

lib {
  config+:: {
    namespace: 'lhw-openproject-prod',
    storage: '10Gi',
    environment: 'production',
  },
  
  statefulset: $.postgres.statefulset,
  service: $.postgres.service,
}
