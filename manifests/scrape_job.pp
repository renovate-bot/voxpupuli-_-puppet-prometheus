# @summary This module manages prometheus scrape jobs.
#
# @note  This define is used to export prometheus scrape settings from nodes to be scraped to the node
#   running prometheus itself.
#   This can be used to make prometheus find instances of your running service or application.
# @param job_name
#  The name of the scrape job. This will be used when collecting resources on the prometheus node.
#  Corresponds to the prometheus::collect_scrape_jobs parameter.
# @param targets
#  Array of hosts and ports in the form "host:port"
# @param labels
#  Labels added to the scraped metrics on the prometheus side, as label:values pairs
# @param collect_dir
#  Directory used for collecting scrape definitions.
#  NOTE: this is a prometheus setting and will be overridden during collection.
# @param ensure
#  Whether the scrape job should be present or absent.
define prometheus::scrape_job (
  String[1] $job_name,
  Array[String[1]] $targets,
  Hash[String[1], String[1]] $labels = {},
  Stdlib::Absolutepath $collect_dir  = undef,
  Enum['present', 'absent'] $ensure = 'present',
) {
  $config = stdlib::to_yaml([
      {
        targets => $targets,
        labels  => $labels,
      },
  ])
  file { "${collect_dir}/${job_name}_${name}.yaml":
    ensure  => stdlib::ensure($ensure, 'file'),
    owner   => 'root',
    group   => $prometheus::group,
    mode    => $prometheus::config_mode,
    content => "# this file is managed by puppet; changes will be overwritten\n${config}",
  }
}
