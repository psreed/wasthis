#Plan to install IBM Package Utility
plan wasthis::install_pu (
  TargetSpec $targets,
  String     $pu_zipfile
) {
  run_command('mkdir -p /opt/was_installers',$targets, '_run_as' => 'root')
  upload_file($pu_zipfile,'/opt/was_installers',$targets, '_run_as' => 'root')
  run_task('install_pu',$targets, '_run_as' => 'root')
}
