class RequestList

  attr_reader :repos

  @@init = false
  @@profiles = {}

  def self.init(config)
    @@request_handlers = config[:request_handlers]
    @@repositories = config[:repositories]

    raise 'Bad RequestList configuration' unless (@@request_handlers && @@repositories)

    begin
      @@repositories[:default][:handler]
      @@repositories[:default][:item_opts] ||= {}
    rescue
      raise 'You must provide a default handler in RequestList configuration.'
    end

    @@request_handlers.each do |key, handler|
      @@request_handlers[key][:list_opts] ||= {}
      @@profiles[handler[:profile]] ||= { :item_mappers => {}}
    end

    Rails.logger.info("RequestList initialized")

    @@init = true
  end


  def self.ensure_profile(profile)
    @@profiles[profile] ||= {:item_mappers => {}}
  end


  def self.register_list_mapper(mapper_class, profile)
    ensure_profile(profile)
    @@profiles[profile][:list_mapper] = mapper_class
    Rails.logger.info("RequestList list mapper registered: #{mapper_class} #{profile}")
  end


  def self.register_item_mapper(mapper_class, profile, record_type)
    ensure_profile(profile)
    @@profiles[profile][:item_mappers][record_type] = mapper_class
    Rails.logger.info("RequestList item mapper registered: #{mapper_class} #{profile} #{record_type}")
  end


  def self.repo_config_for(record)
    @@repositories[:default].merge(@@repositories[record.resolved_repository['repo_code'].downcase] || {})
  end


  def self.show_button_for?(record)
    handler_cfg = handler_config_for(record)
    return false unless handler_cfg
    profile = handler_cfg[:profile]
    return false unless @@profiles[profile][:item_mappers].has_key?(record.class)
    @@profiles[profile][:item_mappers][record.class].new(profile, repo_config_for(record)[:item_opts]).request_permitted?(record)
  end


  def self.handler_config_for(record)
    return false unless defined?(record)
    return false unless record.respond_to?(:resolved_repository)
    return false unless record.resolved_repository

    cfg = repo_config_for(record)
    return false unless cfg[:handler]
    return false unless @@request_handlers[cfg[:handler]]
    @@request_handlers[cfg[:handler]]
  end


  def initialize(records)
    raise 'Call RequestList.init(config) before trying to instantiate.' unless @@init

    @handlers = {}
    @records = records
    @repos = {}

    @records.each do |record|
      @repos[record.resolved_repository['repo_code'].downcase] = record.resolved_repository['name']
      handler_for(record).add(record)
    end
  end


  def handler_for(record)
    repo_args = RequestList.repo_config_for(record)

    handler_args = @@request_handlers[repo_args[:handler]]

    @handlers[repo_args[:handler]] ||= RequestListHandler.new(repo_args[:handler], handler_args[:name],
                                                              handler_args[:profile], handler_args[:url],
                                                              list_mapper_for(handler_args[:profile], handler_args[:list_opts]))

    @handlers[repo_args[:handler]].add_item_mappers_for_repo(record.resolved_repository['repo_code'],
                                                             item_mappers_for(handler_args[:profile], repo_args[:item_opts]))

    @handlers[repo_args[:handler]]
  end


  def list_mapper_for(profile, opts)
    @@profiles[profile][:list_mapper].new(profile, opts)
  end


  def item_mappers_for(profile, opts)
    Hash[@@profiles[profile][:item_mappers].map {|k, v| [k, v.new(profile, opts)]}]
  end


  def handlers
    @handlers.values
  end

end
