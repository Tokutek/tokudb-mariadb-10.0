for suite in tokudb_add_index tokudb_alter_table tokudb_bugs tokudb ; do
    ./mtr --suite=$suite --parallel=auto --force --retry=0 --max-test-fail=0 --testcase-timeout=60 --big-test >$suite.out 2>&1
done