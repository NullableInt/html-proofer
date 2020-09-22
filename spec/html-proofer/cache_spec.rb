# frozen_string_literal: true

require 'spec_helper'

describe 'Cache test' do
  let(:storage_dir) { File.join(FIXTURES_DIR, '/cache') }
  let(:cache_file) { File.join(storage_dir, cache_file_name) }
  let(:cache_file_name) { HTMLProofer::Cache::DEFAULT_CACHE_FILE_NAME }

  let(:default_cache_options) { { storage_dir: storage_dir } }

  let(:logger) { HTMLProofer::Log.new(:debug) }

  def read_cache(cache_file)
    JSON.parse File.read(cache_file)
  end

  context 'with time parser' do
    it 'understands months' do
      now_time = Time.local(2019, 9, 6, 12, 0, 0)
      Timecop.freeze(now_time)

      cache = HTMLProofer::Cache.new(logger, timeframe: '2M')

      check_time = Time.local(2019, 8, 6, 12, 0, 0).to_s

      expect(cache.within_timeframe?(check_time)).to be true

      check_time = Time.local(2019, 5, 6, 12, 0, 0).to_s

      expect(cache.within_timeframe?(check_time)).to be false

      Timecop.return
    end

    it 'understands days' do
      now_time = Time.local(2019, 9, 6, 12, 0, 0)
      Timecop.freeze(now_time)

      cache = HTMLProofer::Cache.new(logger, timeframe: '2d')

      check_time = Time.local(2019, 9, 5, 12, 0, 0).to_s

      expect(cache.within_timeframe?(check_time)).to be true

      check_time = Time.local(2019, 5, 6, 12, 0, 0).to_s

      expect(cache.within_timeframe?(check_time)).to be false

      Timecop.return
    end

    it 'understands weeks' do
      now_time = Time.local(2019, 9, 6, 12, 0, 0)
      Timecop.freeze(now_time)

      cache = HTMLProofer::Cache.new(logger, timeframe: '2w')

      check_time = Time.local(2019, 8, 30, 12, 0, 0).to_s

      expect(cache.within_timeframe?(check_time)).to be true

      check_time = Time.local(2019, 5, 6, 12, 0, 0).to_s

      expect(cache.within_timeframe?(check_time)).to be false

      Timecop.return
    end

    it 'understands hours' do
      now_time = Time.local(2019, 9, 6, 12, 0, 0)
      Timecop.freeze(now_time)

      cache = HTMLProofer::Cache.new(logger, timeframe: '3h')

      check_time = Time.local(2019, 9, 6, 9, 0, 0).to_s

      expect(cache.within_timeframe?(check_time)).to be true

      check_time = Time.local(2019, 5, 6, 12, 0, 0).to_s

      expect(cache.within_timeframe?(check_time)).to be false

      Timecop.return
    end
  end

  context 'with .htmlproofer.log' do
    let(:cache_file_name) { '.htmlproofer.log' }

    it 'knows how to write to cache' do
      broken_link_external_filepath = "#{FIXTURES_DIR}/links/broken_link_external.html"
      expect_any_instance_of(HTMLProofer::Cache).to receive(:write)
      run_proofer(broken_link_external_filepath, :file, cache: { timeframe: '30d', cache_file: cache_file_name }.merge(default_cache_options))

      log = read_cache(cache_file)
      expect(log.keys.length).to eq(2)
      statuses = log.values.map { |h| h['status'] }
      expect(statuses.count(200)).to eq(1)
      expect(statuses.count(0)).to eq(1)
    end
  end

  it 'fails on an invalid date' do
    file = "#{FIXTURES_DIR}/links/broken_link_external.html"
    expect do
      run_proofer(file, :file, cache: { timeframe: '30x' }.merge(default_cache_options))
    end.to raise_error ArgumentError
  end

  context 'within date' do
    let(:cache_file_name) { '.within_date.log' }
    it 'does not write file if timestamp is within date' do
      # this is frozen to within 7 days of the log
      new_time = Time.local(2015, 10, 27, 12, 0, 0)
      Timecop.freeze(new_time)

      expect_any_instance_of(HTMLProofer::Cache).to receive(:write)

      # we expect no add since we are within the timeframe
      expect_any_instance_of(HTMLProofer::Cache).to_not receive(:add)

      run_proofer(['www.github.com'], :links, cache: { timeframe: '30d', cache_file: cache_file_name }.merge(default_cache_options))

      Timecop.return
    end
  end

  context 'not within date' do
    let(:cache_file_name) { '.within_date.log' }
    it 'does write file if timestamp is not within date' do
      # this is frozen to within 7 days of the log
      new_time = Time.local(2015, 10, 27, 12, 0, 0)
      Timecop.freeze(new_time)

      expect_any_instance_of(HTMLProofer::Cache).to receive(:write)

      # we expect an add since we are mocking outside the timeframe
      expect_any_instance_of(HTMLProofer::Cache).to receive(:add).with('www.github.com', nil, 200)

      run_proofer(['www.github.com'], :links, cache: { timeframe: '4d', cache_file: cache_file_name }.merge(default_cache_options))

      Timecop.return
    end
  end

  context 'new url added' do
    let(:cache_file_name) { '.new_url.log' }
    it 'does write file if a new URL is added' do
      # this is frozen to within 7 days of the log
      new_time = Time.local(2015, 10, 20, 12, 0, 0)
      Timecop.freeze(new_time)

      expect_any_instance_of(HTMLProofer::Cache).to receive(:write)
      # we expect one new link to be added, but github.com can stay...
      expect_any_instance_of(HTMLProofer::Cache).to receive(:add).with('www.google.com', nil, 200)

      # ...because it's within the 30d time frame
      run_proofer(['www.github.com', 'www.google.com'], :links, cache: { timeframe: '30d', cache_file: cache_file_name }.merge(default_cache_options))

      Timecop.return
    end
    it 'does write file if a new URL relative is added' do
      # this is frozen to within 7 days of the log
      new_time = Time.local(2015, 10, 20, 12, 0, 0)
      Timecop.freeze(new_time)

      expect_any_instance_of(HTMLProofer::Cache).to receive(:write)
      # we expect one new link to be added, but github.com can stay...
      expect_any_instance_of(HTMLProofer::Cache).to receive(:add).with('/test', nil, 200)

      # ...because it's within the 30d time frame
      run_proofer(['/test'], :links, cache: { timeframe: '30d', cache_file: cache_file_name }.merge(default_cache_options))

      Timecop.return
    end
  end

  context 'recheck failure' do
    let(:cache_file_name) { '.recheck_failure.log' }
    it 'does recheck failures, regardless of cache' do
      # this is frozen to within 7 days of the log
      new_time = Time.local(2015, 10, 27, 12, 0, 0)
      Timecop.freeze(new_time)

      expect_any_instance_of(HTMLProofer::Cache).to receive(:write)

      # we expect the same link to be re-added, even though we are within the time frame,
      # because `foofoofoo.biz` was a failure
      expect_any_instance_of(HTMLProofer::Cache).to receive(:add)

      run_proofer(['http://www.foofoofoo.biz'], :links, cache: { timeframe: '30d', cache_file: cache_file_name }.merge(default_cache_options))

      Timecop.return
    end
  end
end
