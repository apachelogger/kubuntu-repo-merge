#!/usr/bin/env ruby

require 'fileutils'
require 'git'
require 'json'
require 'logger'
require 'logger/colors'
require 'optparse'
require 'tmpdir'

require 'thwait'

# Simple thread pool implementation. Pass a block to run and it runs it in a
# pool.
# Note that the block code should be thread safe...
module BlockingThreadPool
  # Runs the passed block in a pool. This function blocks until all threads are
  # done.
  # @param count the thread count to use for the pool
  def self.run(count = 16, abort_on_exception: true, &block)
    threads = []
    count.times do
      if abort_on_exception
        threads << Thread.new(nil) do
          Thread.current.abort_on_exception = abort_on_exception
          block.call
        end
      else
        threads << Thread.new(nil, &block)
      end
    end
    ThreadsWait.all_waits(threads)
  end
end

origins = []
target = nil

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} --origin ORIGIN --target TARGET GIT-DEBIAN-SUBDIR"

  opts.on('-o ORIGIN_BRANCH', '--origin BRANCH',
          'Branch to merge or branch from. Multiple origins can be given',
          'they will be tried in the sequence they are specified.',
          'If one origin does not exist in a repository the next origin',
          'is tried instead.') do |v|
    origins += v.split(',')
  end

  opts.on('-t TARGET_BRANCH', '--target BARNCH',
          'The target branch to merge into') do |v|
    target = v
  end
end
parser.parse!

COMPONENT = ARGV.last || nil
ARGV.clear

abort parser.help if origins.empty?
abort parser.help if target.nil? || target.empty?
abort parser.help if COMPONENT.nil? || COMPONENT.empty?

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

logger.warn "For component #{COMPONENT} we are going to merge #{origins}" \
            " into #{target}."
logger.warn 'Pushing does not happen until after you had a chance to inspect' \
            ' the results.'

logger.warn "#{origins.join('|')} ⇢ #{target}"

repos = %x[ssh git.debian.org ls /git/pkg-kde/#{COMPONENT}].chop!.gsub!('.git', '').split(' ')
logger.debug "repos: #{repos}"

nothing_to_push = []
Dir.mktmpdir('stabilizer') do |tmpdir|
  Dir.chdir(tmpdir)
  repos.each do |repo|
    log = Logger.new(STDOUT)
    log.level = Logger::INFO
    log.progname = repo
    log.info '----------------------------------'

    git = nil
    if !File.exist?(repo)
      git = Git.clone("debian:#{COMPONENT}/#{repo}", repo)
    else
      git = Git.open(repo)
    end

    git.config('merge.dpkg-mergechangelogs.name',
               'debian/changelog merge driver')
    git.config('merge.dpkg-mergechangelogs.driver',
               'dpkg-mergechangelogs -m %O %A %B %A')

    acted = false
    origins.each do |origin|
      unless git.is_branch?(origin)
        log.error "origin branch '#{origin}' not found"
        next
      end
      if git.is_branch?(target)
        git.checkout(origin)
        git.checkout(target)
        log.warn "Merging #{origin} ⇢ #{target}"
        git.merge(origin, "Merging #{origin} into #{target}\n\nNOCI")
      else
        git.checkout(origin)
        log.warn "Creating #{origin} ⇢ #{target}"
        git.checkout(target, new_branch: true)
      end
      acted = true
      break
    end
    nothing_to_push << repo unless acted
  end

  repos -= nothing_to_push
  logger.progname = ''
  logger.info "The processed repos are in #{Dir.pwd} - Please verify."
  logger.info "The following repos will have #{target} pushed:\n" \
              " #{repos.join(', ')}"
  loop do
    logger.info 'Please type \'c\' to continue'
    break if gets.chop.downcase == 'c'
  end

  repos.each do |repo|
    logger.info "pushing #{repo}"
    git = Git.open(repo)
    git.push('origin', target)
  end
end
