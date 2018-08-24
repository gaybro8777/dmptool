class GuidanceService
  attr_accessor :plan
  attr_accessor :guidance_groups

# TODO: Move the customization below to the new GuidancePresenter once its pulled in
#
# def get_guidance_group_options
#    # find all the themes in this plan
#    # and get the guidance groups they belong to
#    ggroups = []
#    Template.includes(phases: [sections: [questions: [themes: [guidances: [guidance_group: :org]]]]]).find(self.template_id).phases.each do |phase|
#      phase.sections.each do |section|
#        section.questions.each do |question|
#          question.themes.each do |theme|
#            theme.guidances.each do |guidance|
#
#            # START DMPTool customization
#            # ---------------------------------------------------------
#              #ggroups << guidance.guidance_group if guidance.guidance_group.published
#              ggroups << guidance.guidance_group if guidance.guidance_group.published && !guidance.guidance_group.org.is_other?
#            # ---------------------------------------------------------
#            # END DMPTool customization
#
#              # only show published guidance groups
#            end
#          end
#        end
#      end
#    end
#    return ggroups.uniq
#  end

  def initialize(plan)
    @plan = plan
    @guidance_groups = plan.guidance_groups.where(published: true)
  end

  # Returns an Array of orgs according to the guidance related to plan
  # Note the Array is sorted in the following order:
  # First funder org (if the template from the plan is a customization of another)
  # Second template owner's org
  # The orgs from every guidance group selected for this plan
  def orgs
    if !defined?(@orgs)
      @orgs = []
      org_found = lambda{ |orgs, org| return orgs.find{ |lookup_org| lookup_org.id == org.id }.present? }
      orgs_from_annotations.each{ |org| @orgs << org unless org_found.call(@orgs, org) }
      orgs_from_guidance_groups.each{ |org| @orgs << org unless org_found.call(@orgs, org) }
    end
    return @orgs
  end

  def any?(org:nil, question:nil)
    if org.nil?
      if question.present?
        # check each annotation/guidance group for a response to this question
        # Would be nice not to have to crawl the entire list each time we want to know this
        anno = orgs.reduce(false) {|found, o| found || guidance_annotations?(org: o, question: question)}
        if !anno
          return orgs.reduce(anno) {|found, o| found || guidance_groups_by_theme?(org: o, question: question)}
        else
          return anno
        end
      else # question.nil?
        return hashified_annotations? || hashified_guidance_groups?
      end
    end
    return guidance_annotations?(org: org, question: question) ||
    guidance_groups_by_theme?(org: org, question: question)
  end
  # Returns true if exists any guidance_group applicable to the org and question passed
  def guidance_groups_by_theme?(org: nil, question: nil)
    return false unless question.respond_to?(:themes)
    return false unless hashified_guidance_groups.has_key?(org)
    result = guidance_groups_by_theme(org: org, question: question).detect do |gg, theme_hash|
      if theme_hash.present?
        theme_hash.detect{ |theme, guidances| guidances.present? }
      else
        false
      end
    end
    return result.present?
  end
  # Returns true if exists any annotation applicable to the org and question passed
  def guidance_annotations?(org: nil, question: nil)
    return false unless question.respond_to?(:id)
    return false unless hashified_annotations.has_key?(org)
    return hashified_annotations[org].find{ |annotation| (annotation.question_id == question.id) && (annotation.type == "guidance")}.present?
  end
  # Returns a hash of guidance groups for an org and question passed with the following structure:
  # { guidance_group: { theme: [guidance, ...], ... }, ... }
  def guidance_groups_by_theme(org: nil, question: nil)
    raise ArgumentError unless question.respond_to?(:themes)
    question = Question.includes(:themes).find(question.id)
    return {} unless hashified_guidance_groups.has_key?(org)
    return hashified_guidance_groups[org].each_key.reduce({}) do |acc, gg|
      filtered_gg = hashified_guidance_groups[org][gg].each_key.reduce({}) do |acc, theme|
        acc[theme] = hashified_guidance_groups[org][gg][theme] if question.themes.include?(theme)
        acc
      end
      acc[gg] = filtered_gg if filtered_gg.present?
      acc
    end
  end
  # Returns a collection of annotations (type guidance) for an org and question passed
  def guidance_annotations(org: nil, question: nil)
    raise ArgumentError unless question.respond_to?(:id)
    return [] unless hashified_annotations.has_key?(org)
    return hashified_annotations[org].select{ |annotation| (annotation.question_id == question.id) && (annotation.type == "guidance")}
  end


  # filters through the orgs with annotations and guidance groups to create a
  # set of tabs with display names and any guidance/annotations to show
  #
  # question  - The question to which guidance pretains
  #
  # Returns an array of tab hashes.  These
  def tablist(question)
    # start with orgs
    # filter into hash with annotation_presence, main_group presence, and
    display_tabs = []
    orgs.each do |org|
      annotations = guidance_annotations(org: org,question: question)
      groups = guidance_groups_by_theme(org: org,question: question)
      main_groups = groups.select{|group| group.optional_subset == false}
      subsets = groups.reject{|group| group.optional_subset == false}
      if annotations.present? || main_groups.present? # annotations and main group
        # Tab with org.abbreviation
        display_tabs << {name: org.abbreviation, groups: main_groups,
                        annotations: annotations}
      end
      if subsets.present?
        subsets.each_pair do |group,theme|
          display_tabs << {name: group.name.truncate(15), groups:{group => theme}}
        end
      end
    end
    return display_tabs
  end

  private
    def orgs_from_guidance_groups
      if !defined?(@orgs_from_guidance_groups)

      # START DMPTool customization
      # ---------------------------------------------------------
        #@orgs_from_guidance_groups = Org.joins(:guidance_groups).where("guidance_groups.id": guidance_groups.map(&:id)).distinct("orgs.id")
        @orgs_from_guidance_groups = Org.joins(:guidance_groups).where("orgs.is_other": false, "guidance_groups.id": guidance_groups.map(&:id)).distinct("orgs.id")
      # ---------------------------------------------------------
      # END DMPTool customization

      end
      return @orgs_from_guidance_groups
    end
    def orgs_from_annotations
      if !defined?(@orgs_from_annotations)
        @orgs_from_annotations = []
        @orgs_from_annotations << Template.find_by(family_id: plan.template.customization_of).org if plan.template.customization_of.present?

      # START DMPTool customization
      # ---------------------------------------------------------
        #@orgs_from_annotations << plan.template.org
        @orgs_from_annotations << plan.template.org unless plan.template.org.is_other?
      # ---------------------------------------------------------
      # END DMPTool customization

      end
      return @orgs_from_annotations
    end
    def hashified_guidance_groups
      @hashified_guidance_groups ||= hashify_guidance_groups
    end
    def hashified_guidance_groups?
      result = hashified_guidance_groups.detect do |org, gg_hash|
        if gg_hash.present?
          gg_hash.detect do |gg, theme_hash|
            if theme_hash.present?
              theme_hash.detect{ |theme, guidances| guidances.present? }
            else
              false
            end
          end
        else
          false
        end
      end
      return result.present?
    end
    def hashified_annotations
      @hashified_annotations ||= hashify_annotations
    end
    def hashified_annotations?
      return hashified_annotations.detect{ |org, annotations| annotations.present? }.present?
    end
    # Hashifies guidance groups for a plan according to the distinct orgs into the following structure:
    # { org: { guidance_group: { theme: [guidance, ...], ... }, ... }, ... }
    def hashify_guidance_groups
      hashified_guidances = hashify_guidances
      return orgs_from_guidance_groups.reduce({}) do |acc, org|
        org_guidance_groups = hashified_guidances.each_key.select{ |gg| gg.org_id == org.id }
        acc[org] = org_guidance_groups.reduce({}){ |acc, gg| acc[gg] = hashified_guidances[gg]; acc }
        acc
      end
    end
    # Hashifies guidances from a collection of guidance_groups passed into the following structure:
    # { guidance_group: { theme: [guidance, ...], ... }, ... }
    def hashify_guidances
      return guidance_groups.reduce({}) do |acc, gg|
        themes = Theme.includes(:guidances).joins(:guidances).merge(Guidance.where(guidance_group_id: gg.id, published: true))
        acc[gg] = themes.reduce({}) do |acc, theme|
          acc[theme] = theme.guidances
          acc
        end
        acc
      end
    end
    def hashify_annotations
      return orgs_from_annotations.reduce({}) do |acc, org|
        annotations = Annotation.where(org_id: org.id, question_id: plan.template.question_ids)
        acc[org] = annotations.select{ |annotation| annotation.org_id = org.id }
        acc
      end
    end
end
