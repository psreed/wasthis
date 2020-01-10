#Plan to install IBM Package Utility
plan wasthis::install_ibm_package_utility (
  TargetSpec $targets,
  String     $package_utility_zipfile
) {
  run_command('mkdir -p /opt/was_installers',$targets, '_run_as' => 'root')
  upload_file($package_utility_zipfile,'/opt/was_installers/',$targets, '_run_as' => 'root')
  run_task('wasthis::install_ibm_package_utility',$targets, '_run_as' => 'root')
}
