# coding: utf-8
require 'spec_helper'

describe 'rake i18n' do
  describe 'missing' do
    it 'detects missing or identical' do
      TestCodebase.rake_result('i18n:missing').should be_i18n_keys %w(en.used_but_missing.a es.missing_in_es.a es.blank_in_es.a es.same_in_es.a)
    end
  end

  describe 'unused' do
    it 'detects unused' do
      TestCodebase.rake_result('i18n:unused').should be_i18n_keys %w(unused.a)
    end
  end

  describe 'prefill' do
    it 'detects unused' do
      TestCodebase.in_test_app_dir { YAML.load_file('config/locales/es.yml')['es']['missing_in_es'].should be_nil }
      TestCodebase.rake_result('i18n:prefill')
      TestCodebase.in_test_app_dir { YAML.load_file('config/locales/es.yml')['es']['missing_in_es']['a'].should == 'EN_TEXT' }
    end
  end

  # --- setup ---
  BENCH_KEYS = 3000
  before do
    gen_data = ->(v) {
      {
          'ca'            => {'a' => v, 'b' => v, 'c' => v, 'd' => v, 'e' => "#{v}%{i}", 'f' => "#{v}%{i}"},
          'cb'            => {'a' => v, 'b' => "#{v}%{i}"},
          'hash_pattern'  => {'a' => v},
          'hash_pattern2' => {'a' => v},
          'unused'        => {'a' => v},
          'missing_in_es' => {'a' => v},
          'same_in_es'    => {'a' => v},
          'blank_in_es'   => {'a' => v},
          'relative'      => {'index' => {'title' => v}}

      }.tap {|r|
        gen = r["bench"] = {}
        BENCH_KEYS.times.map { |i| gen["key#{i}"] = v }
      }
    }

    en_data                     = gen_data.('EN_TEXT')
    es_data                     = gen_data.('ES_TEXT').except('missing_in_es')
    es_data['same_in_es']['a']  = 'EN_TEXT'
    es_data['blank_in_es']['a'] = ''

    fs = {
        'config/locales/en.yml' => {'en' => en_data}.to_yaml,
        'config/locales/es.yml' => {'es' => es_data}.to_yaml,
        '.i18nignore'           => <<-TEXT,
        ignored_missing_key.a # one key to ignore

                  ignored_pattern.      # ignore the whole pattern
        TEXT
        'app/views/index.html.slim' => <<-SLIM,
        p \#{t('ca.a')} \#{t 'ca.b'} \#{t "ca.c"}
                p \#{t 'ca.d'} \#{t 'ca.f', i: 'world'} \#{t 'ca.e', i: 'world'}
                p \#{t 'missing_in_es.a'} \#{t 'same_in_es.a'} \#{t 'blank_in_es.a'}
                p = t 'used_but_missing.a'
                p = t 'ignored_missing_key.a'
                p = t 'ignored_pattern.some_key'
        SLIM
        'app/views/relative/index.html.slim' => <<-SLIM,
                p = t '.title'
        SLIM
        'app/controllers/events_controller.slim' => <<-RUBY,
        class EventsController < ApplicationController
                   def show
                      redirect_to :edit, notice: I18n.t('cb.a')
                      I18n.t("cb.b", i: "Hello")
                      I18n.t("hash_pattern.\#{some_value}", i: "Hello")
                      I18n.t("hash_pattern2." + some_value, i: "Hello")
                   end
                end
        RUBY
        # test that our algorithms can scale to the order of {BENCH_KEYS} keys.
        'app/heavy.file' => BENCH_KEYS.times.map { |i| "t('bench.key#{i}') " }.join
    }
    TestCodebase.setup fs
  end

  after do
    TestCodebase.teardown
  end
end
