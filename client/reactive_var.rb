require 'set'

class RVar

    attr_reader :value
    @@ticket = 0
    @@group = nil

    def initialize value
        @value = value
        @blocks = {}
    end

    def self.with_group
        @@group = Set.new
        yield
        @@group.each do |blk|
            blk.call
        end
        @@group = nil
    end

    def value= value
        if value != @value
            @value = value
            if @@group.nil?
                @blocks.each_value {|b| b.call}
            else
                @blocks.each_value {|b| @@group.add b}
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

