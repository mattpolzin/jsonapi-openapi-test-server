exec > /tmp/test_server_post_build_log.txt 2>&1

mkdir -p ${BUILT_PRODUCTS_DIR}/Public
cp ${WORKSPACE_PATH}/../../../Public/openapi.yml ${BUILT_PRODUCTS_DIR}/Public/openapi.yml
