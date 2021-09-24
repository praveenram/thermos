# frozen_string_literal: true

module Thermos
  class RefillJob < ActiveJob::Base
    def perform(model_gid)
      model = GlobalID.find(model_gid)
      refill_primary_caches(model)
      refill_dependency_caches(model_gid)
    rescue ActiveRecord::RecordNotFound
      refill_dependency_caches(model_gid)
    end

    def refill_primary_caches(model)
      BeverageStorage.instance.beverages.each do |beverage|
        if beverage.model == model.class && beverage.should_fill?(model)
          Thermos::RebuildCacheJob.perform_later(beverage.key, model.send(beverage.lookup_key))
        end
      end
    end

    def refill_dependency_caches(model_gid)
      gid = GlobalID.parse(model_gid)
      model_class = gid.model_class
      model_id = gid.model_id

      BeverageStorage.instance.beverages.each do |beverage|
        beverage.lookup_keys_for_dep_model(model_class, model_id).each do |lookup_key|
          Thermos::RebuildCacheJob.perform_later(beverage.key, lookup_key)
        end
      end
    end
  end
end
