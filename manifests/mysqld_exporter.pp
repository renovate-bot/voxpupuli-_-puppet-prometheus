# @summary manages prometheus mysqld_exporter
# @see https://github.com/prometheus/mysqld_exporter
# @param cnf_config_path
#  The path to put the my.cnf file
# @param cnf_host
#  The mysql host.
# @param cnf_password
#  The mysql user password.
# @param cnf_port
#  The port for which the mysql host is running.
# @param cnf_socket
#  The socket which the mysql host is running. If defined, host and port are not used.
# @param cnf_user
#  The mysql user to use when connecting.
# @param arch
#  Architecture (amd64 or i386)
# @param bin_dir
#  Directory where binaries are located
# @param config_mode
#  The permissions of the configuration files
# @param download_extension
#  Extension for the release binary archive
# @param download_url
#  Complete URL corresponding to the where the release binary archive can be downloaded
# @param download_url_base
#  Base URL for the binary archive
# @param extra_groups
#  Extra groups to add the binary user to
# @param extra_options
#  Extra options added to the startup command
# @param group
#  Group under which the binary is running
# @param init_style
#  Service startup scripts style (e.g. rc, upstart or systemd)
# @param install_method
#  Installation method: url or package (only url is supported currently)
# @param manage_group
#  Whether to create a group for or rely on external code for that
# @param manage_service
#  Should puppet manage the service?
# @param manage_user
#  Whether to create user or rely on external code for that
# @param os
#  Operating system (linux is the only one supported)
# @param package_ensure
#  If package, then use this for package ensure default 'latest'
# @param package_name
#  The binary package name - not available yet
# @param purge_config_dir
#  Purge config files no longer generated by Puppet
# @param restart_on_change
#  Should puppet restart the service on configuration change?
# @param service_enable
#  Whether to enable the service from puppet
# @param service_ensure
#  State ensured for the service
# @param service_name
#  Name of the mysqld exporter service
# @param user
#  User which runs the service
# @param version
#  The binary release version
# @param proxy_server
#  proxy server, with port number if needed. ie: https://example.com:8080
# @param proxy_type
#  proxy server type
# @param web_config_file
#  Path of file where the web-config will be saved to
# @param web_config_content
#  Unless empty the content of the web-config yaml which will handed over as option to the exporter
# @param cnf_ssl_ca
#  The path name of the Certificate Authority (CA) certificate file in PEM format.
# @param cnf_ssl_cert
#  The path name of the client SSL public key certificate file in PEM format.
# @param cnf_ssl_key
#  The path name of the client SSL private key file in PEM format.
class prometheus::mysqld_exporter (
  String $download_extension = 'tar.gz',
  Prometheus::Uri $download_url_base = 'https://github.com/prometheus/mysqld_exporter/releases',
  Array $extra_groups = [],
  String[1] $group = 'mysqld-exporter',
  String[1] $package_ensure = 'latest',
  String[1] $package_name = 'mysqld_exporter',
  String[1] $user = 'mysqld-exporter',
  # renovate: depName=prometheus/mysqld_exporter
  String[1] $version                                         = '0.16.0',
  String[1] $service_name = 'mysqld_exporter',
  Stdlib::Absolutepath $cnf_config_path                      = '/etc/mysqld_exporter-my.cnf',
  Stdlib::Host $cnf_host                                     = localhost,
  Stdlib::Port $cnf_port                                     = 3306,
  String[1] $cnf_user                                        = login,
  Variant[Sensitive[String],String] $cnf_password            = 'password',
  Optional[Stdlib::Absolutepath] $cnf_socket                 = undef,
  Boolean $purge_config_dir                                  = true,
  Boolean $restart_on_change                                 = true,
  Boolean $service_enable                                    = true,
  Stdlib::Ensure::Service $service_ensure                    = 'running',
  Prometheus::Initstyle $init_style                          = $prometheus::init_style,
  Prometheus::Install $install_method                        = $prometheus::install_method,
  Boolean $manage_group                                      = true,
  Boolean $manage_service                                    = true,
  Boolean $manage_user                                       = true,
  String[1] $os                                              = downcase($facts['kernel']),
  Optional[String[1]] $extra_options                         = undef,
  Optional[Prometheus::Uri] $download_url                    = undef,
  String[1] $config_mode                                     = $prometheus::config_mode,
  String[1] $arch                                            = $prometheus::real_arch,
  Stdlib::Absolutepath $bin_dir                              = $prometheus::bin_dir,
  Boolean $export_scrape_job                                 = false,
  Optional[Stdlib::Host] $scrape_host                        = undef,
  Stdlib::Port $scrape_port                                  = 9104,
  String[1] $scrape_job_name                                 = 'mysql',
  Optional[Hash] $scrape_job_labels                          = undef,
  Optional[String[1]] $proxy_server                          = undef,
  Optional[Enum['none', 'http', 'https', 'ftp']] $proxy_type = undef,
  Stdlib::Absolutepath $web_config_file                      = '/etc/mysqld_exporter_web-config.yml',
  Prometheus::Web_config $web_config_content                 = {},
  Optional[Stdlib::Absolutepath] $cnf_ssl_ca                 = undef,
  Optional[Stdlib::Absolutepath] $cnf_ssl_cert               = undef,
  Optional[Stdlib::Absolutepath] $cnf_ssl_key                = undef,
) inherits prometheus {
  #Please provide the download_url for versions < 0.9.0
  $real_download_url = pick($download_url,"${download_url_base}/download/v${version}/${package_name}-${version}.${os}-${arch}.${download_extension}")
  $notify_service = $restart_on_change ? {
    true    => Service[$service_name],
    default => undef,
  }

  $_cnf_settings = {
    'user'     => $cnf_user,
    'password' => $cnf_password,
    'port'     => $cnf_port,
    'host'     => $cnf_host,
    'socket'   => $cnf_socket,
    'ssl-ca'   => $cnf_ssl_ca,
    'ssl-cert' => $cnf_ssl_cert,
    'ssl-key'  => $cnf_ssl_key,
  }.filter |$k, $v| { $v != undef }

  file { $cnf_config_path:
    ensure  => file,
    mode    => $config_mode,
    owner   => $user,
    group   => $group,
    content => Sensitive(
      epp(
        'prometheus/my.cnf.epp',
        { 'settings' => $_cnf_settings }
      )
    ),
    notify  => $notify_service,
  }

  $_web_config_ensure = $web_config_content.empty ? {
    true    => absent,
    default => file,
  }

  file { $web_config_file:
    ensure  => $_web_config_ensure,
    owner   => $user,
    group   => $group,
    mode    => '0640',
    content => $web_config_content.stdlib::to_yaml,
    notify  => $notify_service,
  }

  $_web_config = if $web_config_content.empty {
    ''
  } else {
    "--web.config.file=${$web_config_file}"
  }
  $_config_myconf = if versioncmp($version, '0.11.0') < 0 {
    "-config.my-cnf=${cnf_config_path}"
  } else {
    "--config.my-cnf=${cnf_config_path}"
  }

  $options = [
    $_config_myconf,
    $extra_options,
    $_web_config,
  ].filter |$x| { !$x.empty }.join(' ')

  prometheus::daemon { $service_name:
    install_method     => $install_method,
    version            => $version,
    download_extension => $download_extension,
    os                 => $os,
    arch               => $arch,
    real_download_url  => $real_download_url,
    bin_dir            => $bin_dir,
    notify_service     => $notify_service,
    package_name       => $package_name,
    package_ensure     => $package_ensure,
    manage_user        => $manage_user,
    user               => $user,
    extra_groups       => $extra_groups,
    group              => $group,
    manage_group       => $manage_group,
    purge              => $purge_config_dir,
    options            => $options,
    init_style         => $init_style,
    service_ensure     => $service_ensure,
    service_enable     => $service_enable,
    manage_service     => $manage_service,
    export_scrape_job  => $export_scrape_job,
    scrape_host        => $scrape_host,
    scrape_port        => $scrape_port,
    scrape_job_name    => $scrape_job_name,
    scrape_job_labels  => $scrape_job_labels,
    proxy_server       => $proxy_server,
    proxy_type         => $proxy_type,
  }
}
