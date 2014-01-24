#!/usr/bin/env ruby 

require 'digest/sha1'

class Miner
  USERNAME = 'user-nj7ibw6l'

  def initialize(*args)
    reset
    @counter = 0
    @timestamp = Time.now.to_i
    while solve
      @timestamp = Time.now.to_i
      print '.' if @counter % 10000 == 0
    end
    p "You're done!"
  end
  
  def solve
    if sha1 < difficulty
      p "Success! #{sha1}"
      `git hash-object -t commit --stdin -w <<< "#{body}"`
      `git reset --hard "#{sha1}"`
      return false if system 'git push -ff origin master'
      reset
      return true
    else
      @counter += 1
      return true
    end
  end

  def sha1
    Digest::SHA1.hexdigest(store)
  end

  def sha1_test
    `git hash-object -t commit --stdin -w <<< "#{body}"`.gsub("\n","")
  end

  def difficulty
    @difficulty ||= File.read('difficulty.txt').gsub("\n","")
  end

  def store 
    "#{header}#{body}\n"
  end

  def header
    "commit #{body.length+1}\0"
  end

  def body
    "tree #{tree}\n" +
    "parent #{parent}\n" + 
    "author CTF user <me@example.com> #{@timestamp} +0000\n" + 
    "committer CTF user <me@example.com> #{@timestamp} +0000\n" +
    "Give me a Gitcoin " +
    "#{@counter}\n"
  end

  def parent
    @parent ||= `git rev-parse HEAD`.gsub("\n","")
  end

  def tree
    @tree ||= `git write-tree`.gsub("\n","")
  end

  def reset
    @difficulty = @parent = @tree = nil
    `git fetch origin master`
    `git reset --hard origin/master`
    prepare_index
    p difficulty
  end

  def prepare_index
    ledger = File.open('LEDGER.txt') 
    unless ledger.read.include? USERNAME
      f = File.open('LEDGER.txt','a') << "#{USERNAME}: 1\n" 
      f.close
    end
    ledger.close
    `git add LEDGER.txt`
  end

end

threads = []
threads << Thread.new { Miner.new }
threads << Thread.new {
  while true
    local = `git describe --always --abbrev=16`.gsub("\n","")
    remote = `git ls-remote origin 'refs/heads/master'`.gsub("\n","")
    unless remote.include? local
      p 'Updated Repository, resetting!'
      threads[0].kill
      threads[0] = Thread.new { Miner.new }
    end
    sleep 10
  end
}
threads.each { |t| t.join }