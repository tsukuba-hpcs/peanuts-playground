# setup spack 
spack_user_root="${HOME}/.cache/spack"
if [ -s "${spack_user_root}" ]; then
  . "${spack_user_root}/share/spack/setup-env.sh"
fi
