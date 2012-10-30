require 'work_queue'
require 'parallizer/version'
require 'parallizer/proxy'
require 'parallizer/method_call_notifier'

class Parallizer
  WORK_QUEUE_SIZE = 10
  
  attr_reader :calls, :call_infos, :client, :proxy, :options
  
  def initialize(client, options = {})
    @client = client
    @options = {:retries => 0}.merge(options)
    @call_infos = {}
  end
  
  def add
    MethodCallNotifier.new do |*args|
      add_call(*args)
    end
  end
  
  def calls
    @call_infos.keys
  end
  
  def add_call(method_name, *args)
    raise ArgumentError, "Cannot add calls after proxy has been generated" if @proxy
    
    method_name_and_args = [method_name.to_sym, *args]
    return if call_infos[method_name_and_args]
    
    call_info = {
      :complete? => false,
      :result => nil,
      :exception => nil,
      :retries => options[:retries]
    }
    call_infos[method_name_and_args] = call_info
  end
  
  def create_proxy
    raise ArgumentError, "Cannot create another proxy" if @proxy
    
    execute
    
    Parallizer::Proxy.new(client, call_infos)
  end
  
  private
  
  def self.work_queue
    # TODO: share the work queue among calling threads
    Thread.current[:parallizer_work_queue] ||= WorkQueue.new(WORK_QUEUE_SIZE)
  end
  
  def execute
    call_infos.each do |method_name_and_args, call_info|
      Parallizer.work_queue.enqueue_b do
        (call_info[:retries] + 1).times do
          begin
            call_info[:exception] = nil # reset exception before each send attempt
            call_info[:result] = client.send(*method_name_and_args)
            break # success
          rescue Exception => e
            call_info[:exception] = e
          end
        end
      end
    end
    
    Parallizer.work_queue.join

    Parallizer::Proxy.new(client, call_infos)
  end
end
