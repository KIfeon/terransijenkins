// Groovy script for Active Choices Parameter in Jenkins UI
// Copy this into the Jenkins parameter configuration

try {
    // Use separate commands to avoid complex escaping
    def vpcCmd = ['aws', 'ec2', 'describe-vpcs', 
                  '--region', 'us-east-1',
                  '--filters', 'Name=tag:Environment,Values=*',
                  '--query', 'Vpcs[?contains(Tags[?Key==`Environment`].Value, `lab`)].Tags[?Key==`Environment`].Value',
                  '--output', 'text']
    
    def keyCmd = ['aws', 'ec2', 'describe-key-pairs',
                  '--region', 'us-east-1', 
                  '--query', 'KeyPairs[?contains(KeyName, `lab`)].KeyName',
                  '--output', 'text']
    
    def allLabs = []
    
    // Get VPC labs
    def proc1 = vpcCmd.execute()
    proc1.waitFor()
    if (proc1.exitValue() == 0) {
        def vpcs = proc1.text.trim()
        if (vpcs && !vpcs.isEmpty() && vpcs != "None") {
            vpcs.split('\\t|\\n').each { lab ->
                def cleanLab = lab?.trim()
                if (cleanLab && cleanLab.contains('lab')) {
                    allLabs.add(cleanLab)
                }
            }
        }
    }
    
    // Get SSH key labs
    def proc2 = keyCmd.execute()
    proc2.waitFor()
    if (proc2.exitValue() == 0) {
        def keys = proc2.text.trim()
        if (keys && !keys.isEmpty() && keys != "None") {
            keys.split('\\t|\\n').each { key ->
                def cleanKey = key?.trim()
                if (cleanKey && cleanKey.contains('lab')) {
                    // Remove -key suffix
                    def labName = cleanKey.replaceAll('-key$', '')
                    if (labName) {
                        allLabs.add(labName)
                    }
                }
            }
        }
    }
    
    def uniqueLabs = allLabs.unique().sort()
    
    def result = []
    if (uniqueLabs.size() == 0) {
        result.add("❌ Aucun lab trouvé")
        result.add("🔄 Actualiser la page")
    } else {
        result.add("🔍 Sélectionnez un lab:")
        uniqueLabs.each { lab ->
            if (lab && lab.trim()) {
                result.add("🧪 " + lab.trim())
            }
        }
    }
    
    return result
    
} catch (Exception e) {
    return ["❌ Erreur: " + e.getMessage(), "🔄 Vérifiez configuration AWS"]
}
