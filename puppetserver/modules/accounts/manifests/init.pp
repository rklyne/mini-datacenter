class accounts {

  include accounts::groups

  $rootgroup = $osfamily ? {
    'Debian'  => 'sudo',
    'RedHat'  => 'wheel',
    default   => warning('This distribution is not supported by the Accounts module'),
  }


  user { 'rktest':
    ensure      => present,
    home        => '/home/rktest',
    shell       => '/bin/bash',
    managehome  => true,
    gid         => 'rktest',
    groups      => "$rootgroup",
    password    => '$1$P8BY6FCp$l3Rzpukwog/fND/bKBkW//',
    }

}
