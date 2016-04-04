class RVar

    attr_reader :value
    @@ticket = 0

    def initialize value
        @value = value
        @blocks = {}
    end

    def value= value
        if value != @value
            @value = value
            @blocks.each_value {|b| b.call}
            #@blocks.each {|b| b.call}
        end
    end

    def add block
        id = @@ticket
        @@ticket += 1
        @blocks[id] = block
        id
        #@blocks << block
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

