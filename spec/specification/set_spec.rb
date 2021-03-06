require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Specification::Set do

    describe 'In general' do
      before do
        @source = Source.new(fixture('spec-repos/master'))
        @set = Spec::Set.new('CocoaLumberjack', @source)
      end

      it 'returns the name of the pod' do
        @set.name.should == 'CocoaLumberjack'
      end

      it 'returns the versions available for the pod ordered from highest to lowest' do
        @set.versions.should.all { |v| v.is_a?(Version) }
        @set.versions.map(&:to_s).should == %w(1.6.2 1.6.1 1.6 1.3.3 1.3.2 1.3.1 1.3 1.2.3 1.2.2 1.2.1 1.2 1.1 1.0)
      end

      it 'returns the highest version available for the pod' do
        @set.highest_version.should == Version.new('1.6.2')
      end

      it 'returns the path of the spec with the highest version' do
        @set.highest_version_spec_path.should == @source.data_provider.repo + 'CocoaLumberjack/1.6.2/CocoaLumberjack.podspec'
      end

      it 'checks if the dependency of the specification is compatible with existing requirements' do
        @set.required_by(Dependency.new('CocoaLumberjack', '1.2'), 'Spec')
        @set.required_by(Dependency.new('CocoaLumberjack', '< 1.2.1'), 'Spec')
        @set.required_by(Dependency.new('CocoaLumberjack', '> 1.1'), 'Spec')
        @set.required_by(Dependency.new('CocoaLumberjack', '~> 1.2.0'), 'Spec')
        @set.required_by(Dependency.new('CocoaLumberjack'), 'Spec')
        lambda do
          @set.required_by(Dependency.new('CocoaLumberjack', '< 1.0'), 'Spec')
        end.should.raise Informative
      end

      it "raises if the required version doesn't exist" do
        should.raise Informative do
          @set.required_by(Dependency.new('CocoaLumberjack', '< 1.0'), 'Spec')
        end
      end

      it 'can test if it is equal to another set' do
        @set.should == Spec::Set.new('CocoaLumberjack', @source)
        @set.should.not == Spec::Set.new('RestKit', @source)
      end

      it 'returns a hash representation' do
        spec_path = @source.data_provider.repo + 'CocoaLumberjack/1.6.2/CocoaLumberjack.podspec'
        @set.to_hash.should == {
          'name' => 'CocoaLumberjack',
          'versions' => {
            'master' => [
              '1.6.2', '1.6.1', '1.6', '1.3.3', '1.3.2', '1.3.1', '1.3', '1.2.3', '1.2.2',
              '1.2.1', '1.2', '1.1', '1.0'
            ]
          },
          'highest_version' => '1.6.2',
          'highest_version_spec' => spec_path.to_s
        }
      end

      #--------------------------------------#

      before do
        @set.required_by(Dependency.new('CocoaLumberjack', '< 1.2.1'), 'Spec')
      end

      it 'returns the version required for the dependency' do
        @set.required_version.should == Version.new('1.2')
      end

      it 'returns the acceptable versions according to the requirements stored' do
        @set.acceptable_versions.map(&:to_s).should == ['1.2', '1.1', '1.0']
      end

      it 'returns the specification for the required version' do
        @set.specification.name.should == 'CocoaLumberjack'
        @set.specification.version.should == Version.new('1.2')
      end

      it 'ignores dot files when getting the version directories' do
        `touch #{fixture('spec-repos/master/CocoaLumberjack/.DS_Store')}`
        should.not.raise do
          @set.versions
        end
      end

      it 'raises if a version is incompatible with the activated version' do
        dep = Dependency.new('CocoaLumberjack', '1.2.1')
        should.raise Informative do
          @set.required_by(dep, 'Spec')
        end
      end

      it 'accepts a requirement if it allows supported versions' do
        dep = Dependency.new('CocoaLumberjack', '< 1.1')
        @set.required_by(dep, 'Spec')
        @set.acceptable_versions.map(&:to_s).should == ['1.0']
      end
    end
    
    #-------------------------------------------------------------------------#
    # Reproduce issue #73: Pre-release versions should not be matched when using the < version operator 
    describe "Regarding pre-release versions" do
      before do
        @source = Source.new(fixture('spec-repos/master'))
        @set = Spec::Set.new('AFNetworking', @source)
        @set.required_by(Dependency.new('AFNetworking', '< 1.0'), 'Spec')
      end
      
      it "returns the highest non-pre-release version for the dependency that uses the < operator" do
        @set.required_version.should == Version.new('0.10.1')
      end
            
      # Pre-release version can be explicitly specified
      before do
        @source = Source.new(fixture('spec-repos/master'))
        @set = Spec::Set.new('AFNetworking', @source)
        @set.required_by(Dependency.new('AFNetworking', '1.0RC3'), 'Spec')
      end
      
      it "returns the pre-release version specified explicitly for the dependency" do
        @set.required_version.should == Version.new('1.0RC3')
      end
      
      before do
        @source = Source.new(fixture('spec-repos/master'))
        @set = Spec::Set.new('AFNetworking', @source)
        @set.required_by(Dependency.new('AFNetworking', '<= 1.0RC3'), 'Spec')
      end
      
      it "returns the highest pre-release version for the dependency that uses the <= operator" do
        @set.required_version.should == Version.new('1.0RC3')
      end
            
    end


    #-------------------------------------------------------------------------#

    describe 'Concerning multiple sources' do

      before do
        # JSONKit is in test repo has version 1.4 (duplicated) and the 999.999.999.
        @set = Source::Aggregate.new(fixture('spec-repos')).search_by_name('JSONKit').first
      end

      it 'returns the sources where a podspec is available' do
        @set.sources.map(&:name).should == %w(master test_repo)
      end

      it 'returns all the available versions sorted from biggest to lowest' do
        @set.versions.map(&:to_s).should == %w(999.999.999 1.5pre 1.4)
      end

      it 'returns all the available versions by source sorted from biggest to lowest' do
        hash = {}
        @set.versions_by_source.each { |source, versions| hash[source.name] = versions.map(&:to_s) }
        hash['master'].should == %w(1.5pre 1.4)
        hash['test_repo'].should == %w(999.999.999 1.4)
        hash.keys.sort.should == %w(master test_repo)
      end

      it 'returns the specification from the `master` source for the required version' do
        dep = Dependency.new('JSONKit', '1.5pre')
        @set.required_by(dep, 'Spec')
        spec = @set.specification
        spec.name.should == 'JSONKit'
        spec.version.to_s.should == '1.5pre'
        spec.defined_in_file.should == fixture('spec-repos/master/JSONKit/1.5pre/JSONKit.podspec')
      end

      it 'returns the specification from `test_repo` source for the required version' do
        dep = Dependency.new('JSONKit', '999.999.999')
        @set.required_by(dep, 'Spec')
        spec = @set.specification
        spec.name.should == 'JSONKit'
        spec.version.to_s.should == '999.999.999'
        spec.defined_in_file.should == fixture('spec-repos/test_repo/Specs/JSONKit/999.999.999/JSONKit.podspec')
      end

      it 'prefers sources by alphabetical order' do
        dep = Dependency.new('JSONKit', '1.4')
        @set.required_by(dep, 'Spec')
        spec = @set.specification
        spec.name.should == 'JSONKit'
        spec.version.to_s.should == '1.4'
        spec.defined_in_file.should ==  fixture('spec-repos/master/JSONKit/1.4/JSONKit.podspec')
      end
    end
  end

  #---------------------------------------------------------------------------#

  describe Specification::Set::External do

    before do
      @spec = Spec.from_file(fixture('BananaLib.podspec'))
      @set = Spec::Set::External.new(@spec)
    end

    it 'returns the specification' do
      @set.specification.should == @spec
    end

    it 'returns the name' do
      @set.name.should == 'BananaLib'
    end

    it 'returns whether it is equal to another set' do
      @set.should == Spec::Set::External.new(@spec)
    end

    it 'returns the version of the specification' do
      @set.versions.map(&:to_s).should == ['1.0']
    end

    it "doesn't nil the initialization specification on #required_by" do
      @set.required_by(Dependency.new('BananaLib', '1.0'), 'Spec')
      @set.specification.should == @spec
    end

    it 'raises if asked for the specification path' do
      should.raise StandardError do
        @set.specification_path
      end
    end

    it "raises if the required version doesn't match the specification" do
      should.raise Informative do
        @set.required_by(Dependency.new('BananaLib', '< 1.0'), 'Spec')
      end
    end
  end
end
