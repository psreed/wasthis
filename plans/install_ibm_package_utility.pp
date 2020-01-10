#Plan to install IBM Package Utility
plan wasthis::install_ibm_package_utility (
  TargetSpec $targets,
  String     $package_utility_zipfile
) {

  #Specify root directory for remote installer files.
  $remote_install_dir = '/opt/was_installers'
  $remote_ibm_pu_zipfile = 'ibm_pu.zip'

  # Create Remote Installers Directory
  run_command(
    "[ ! -d '${remote_install_dir}' ] && mkdir -p \"${remote_install_dir}\"; echo 0",
    $targets,
    'Ensuring Installation Directory Exists',
    '_run_as' => 'root'
  )

  $testvar='This is a happy test variable.'
  $result=run_command("/bin/sh -c \"if [ 0 -eq 0 ]; then echo \\\"${testvar}\\\"; fi\"", $targets, 'Test the things!')

  fail_plan('Early Exit')

  #check local and remote MD5 (to avoid download and save time if it's already the same file)
  $file_check=run_command(
    "if [ -f \"${remote_install_dir}/${remote_ibm_pu_zipfile}\"]; then echo 'Hello'; fi",
    $targets,
    'Checking if Remote File already exists',
    '_run_as' => 'root'
  )


$remote_md5=run_command(
    "md5=$(md5sum ${remote_install_dir}/${remote_ibm_pu_zipfile} | awk '{print \$1}'); echo \$md5",
    'localhost',
    'Getting MD5 of Remote file (if it exists)',
    '_run_as' => 'root',
    '_catch_errors' => true
  )

  $remote_md5.to_data.each |$rhash| {
    notice($rhash['result']['stdout'])
  }
  if $remote_md5.ok {
    #run_command("rmd5=${remote_md5}; lmd5=$(md5sum ${package_utility_zipfile}); echo \"localMD5: \${lmd5}\"; echo \"RemoteMD5: \${rmd5}\"",'localhost') #lint:ignore:140chars
  }


#  upload_file($package_utility_zipfile,"${remote_install_dir}/ibm_pu.zip",$targets, '_run_as' => 'root')
  run_task(
    'wasthis::install_ibm_package_utility',
    $targets,
    'IBM Package Utility Installation Task',
    'install_dir' => $remote_install_dir,
    'filename'    => 'ibm_pu.zip',
    '_run_as'     => 'root'
  )
}
