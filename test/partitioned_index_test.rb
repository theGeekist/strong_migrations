require_relative "test_helper"

class AddPartitionedIndex < TestMigration
  def change
    add_index :partitioned_events, :account_id
  end
end

class AddPartitionedIndexConcurrently < TestMigration
  disable_ddl_transaction!

  def change
    add_index :partitioned_events, :account_id, algorithm: :concurrently
  end
end

class RemovePartitionedIndex < TestMigration
  def change
    remove_index :partitioned_events, :account_id
  end
end

class RemovePartitionedIndexConcurrently < TestMigration
  disable_ddl_transaction!

  def change
    remove_index :partitioned_events, :account_id, algorithm: :concurrently
  end
end

class AddLeafIndexConcurrently < TestMigration
  disable_ddl_transaction!

  def change
    add_index :partitioned_events_1, :account_id, algorithm: :concurrently
  end
end

class PartitionedIndexTest < Minitest::Test
  def setup
    skip unless postgresql?

    connection.execute("CREATE TABLE partitioned_events (id bigint, account_id bigint) PARTITION BY RANGE (id)")
    connection.execute("CREATE TABLE partitioned_events_1 PARTITION OF partitioned_events FOR VALUES FROM (0) TO (100)")
  end

  def teardown
    connection.execute("DROP TABLE IF EXISTS partitioned_events CASCADE") if postgresql?
  end

  def test_add_index_suggests_no_unsupported_concurrently
    assert_unsafe AddPartitionedIndex, "partitioned parent table"
  end

  def test_add_index_safe_by_default_stops_before_postgres_error
    with_option(:safe_by_default, true) do
      assert_unsafe AddPartitionedIndex, "partitioned parent table"
    end
  end

  def test_add_index_explicit_concurrently_has_dedicated_error
    assert_unsafe AddPartitionedIndexConcurrently, "partitioned parent table"
  end

  def test_remove_index_suggests_no_unsupported_concurrently
    add_parent_index
    StrongMigrations.enable_check(:remove_index)
    assert_unsafe RemovePartitionedIndex, "partitioned parent table"
  ensure
    StrongMigrations.disable_check(:remove_index)
  end

  def test_remove_index_safe_by_default_stops_before_postgres_error
    add_parent_index
    with_option(:safe_by_default, true) do
      assert_unsafe RemovePartitionedIndex, "partitioned parent table"
    end
  end

  def test_remove_index_explicit_concurrently_has_dedicated_error
    add_parent_index
    assert_unsafe RemovePartitionedIndexConcurrently, "partitioned parent table"
  end

  def test_leaf_partition_can_create_index_concurrently
    migrate AddLeafIndexConcurrently
    assert connection.index_exists?(:partitioned_events_1, :account_id)
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def add_parent_index
    connection.execute("CREATE INDEX ON partitioned_events (account_id)")
  end
end
