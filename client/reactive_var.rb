require 'set'

class RVar

    attr_reader :value
    @@ticket = 0
    @@group = nil
    @@backup = {}

    def initialize value
        @value = value
        @blocks = {}
        @forms = Set.new
    end

    def self.alert_if_dirty
        @@group = Set.new
        @@backup = []
        begin
            yield
        rescue
            @@backup.each do |v|
                v.call
            end
            raise
        else
            @@group.each do |blk|
                blk.call
            end
        ensure
            @@group = nil
            @@backup = []
        end
    end

    def self.rgrouping
        self.alert_if_dirty
    end

    def value= value
        @forms.each { |form| raise Exception if form.dirty?}
        old_value = @value
        if value != @value
            @value = value
            if @@group.nil?
                @blocks.each_value {|b| b.call}
            else
                @blocks.each_value {|b| @@group.add b; @@backup << lambda{@value = old_value}}
            end
        end
    end

    def add block
        id = @@ticket
        @@ticket += 1
        @blocks[id] = block
        id
    end

    def remove id
        @blocks.delete id
    end

    def add_form form
        @forms.add form
    end

    def remove_form form
        @forms.delete form
    end
end

def reactive(*args, &block)
    ret = {}
    args.each do |v|
        id = v.add(block)
        ret[id] = v
    end
    block.call
    ret
end

