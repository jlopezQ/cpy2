require 'spec_helper'

describe GitStats::GitData::Repo do
  let(:repo) { build(:repo) }
  let(:expected_authors) { [
      build(:author, repo: repo, name: "John Doe", email: "john.doe@gmail.com"),
      build(:author, repo: repo, name: "Joe Doe", email: "joe.doe@gmail.com")
  ] }

  describe 'commit range' do
    it 'should return HEAD by default' do
      repo.commit_range.should == 'HEAD'
    end

    it 'should return last_commit if it was given' do
      repo = build(:repo, last_commit_hash: 'abc')
      repo.commit_range.should == 'abc'
    end

    it 'should return range from first_commit to HEAD if first_commit was given' do
      repo = build(:repo, first_commit_hash: 'abc')
      repo.commit_range.should == 'abc..HEAD'
    end

    it 'should return range from first to last commit if both were given' do
      repo = build(:repo, first_commit_hash: 'abc', last_commit_hash: 'def')
      repo.commit_range.should == 'abc..def'
    end

    context 'git commands using range' do
      let(:repo) { build(:repo, first_commit_hash: 'abc', last_commit_hash: 'def') }

      it 'should affect authors command' do
        repo.should_receive(:run).with('git shortlog -se abc..def').and_return("")
        repo.authors
      end

      it 'should affect commits command' do
        repo.should_receive(:run).with("git rev-list --pretty=format:'%h|%at|%ai|%aE' abc..def | grep -v commit").and_return("")
        repo.commits
      end

      it 'should affect project version command' do
        repo.should_receive(:run).with('git rev-parse --short abc..def').and_return("")
        repo.project_version
      end
    end
  end

  describe 'command observers' do
    context 'should be invoked after every command' do
      it 'should accept block' do
        command_runner = double('command_runner')
        repo = build(:repo, command_runner: command_runner)

        observer = double('observer')
        repo.add_command_observer { |command, result| observer.invoked(command, result) }
        command_runner.should_receive(:run).with(repo.path, 'aa').and_return('bb')
        observer.should_receive(:invoked).with('aa', 'bb')

        repo.run('aa')
      end

      it 'should accept Proc' do
        command_runner = double('command_runner')
        repo = build(:repo, command_runner: command_runner)

        observer = double('observer')
        repo.add_command_observer(observer)
        command_runner.should_receive(:run).with(repo.path, 'aa').and_return('bb')
        observer.should_receive(:call).with('aa', 'bb')

        repo.run('aa')
      end
    end
  end

  describe 'git output parsing' do
    context 'invoking authors command' do
      before do
        repo.should_receive(:run).with('git shortlog -se HEAD').and_return("   156	John Doe <john.doe@gmail.com>
    53	Joe Doe <joe.doe@gmail.com>
")
      end
      it 'should parse git shortlog output to authors hash' do
        repo.authors.should == expected_authors
      end

      it 'should parse git revlist output to date sorted commits array' do
        repo.should_receive(:run).with("git rev-list --pretty=format:'%h|%at|%ai|%aE' HEAD | grep -v commit").and_return(
            "e4412c3|1348603824|2012-09-25 22:10:24 +0200|john.doe@gmail.com
ce34874|1347482927|2012-09-12 22:48:47 +0200|joe.doe@gmail.com
5eab339|1345835073|2012-08-24 21:04:33 +0200|john.doe@gmail.com
")

        repo.commits.should == [
            GitStats::GitData::Commit.new(
                repo: repo, hash: "5eab339", stamp: "1345835073", date: DateTime.parse("2012-08-24 21:04:33 +0200"),
                author: repo.authors.by_email("john.doe@gmail.com")),
            GitStats::GitData::Commit.new(
                repo: repo, hash: "ce34874", stamp: "1347482927", date: DateTime.parse("2012-09-12 22:48:47 +0200"),
                author: repo.authors.by_email("joe.doe@gmail.com")),
            GitStats::GitData::Commit.new(
                repo: repo, hash: "e4412c3", stamp: "1348603824", date: DateTime.parse("2012-09-25 22:10:24 +0200"),
                author: repo.authors.by_email("john.doe@gmail.com"))
        ]
      end
    end
    it 'should parse git rev-parse command to project version' do
      repo.should_receive(:run).with('git rev-parse --short HEAD').and_return('xyz')
      repo.project_version.should == 'xyz'
    end
  end
end